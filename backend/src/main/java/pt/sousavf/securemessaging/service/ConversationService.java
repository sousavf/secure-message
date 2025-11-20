package pt.sousavf.securemessaging.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pt.sousavf.securemessaging.entity.Conversation;
import pt.sousavf.securemessaging.entity.ConversationParticipant;
import pt.sousavf.securemessaging.entity.User;
import pt.sousavf.securemessaging.repository.ConversationRepository;
import pt.sousavf.securemessaging.repository.ConversationParticipantRepository;
import pt.sousavf.securemessaging.repository.ConversationRedisRepository;
import pt.sousavf.securemessaging.repository.MessageRepository;
import pt.sousavf.securemessaging.repository.MessageRedisRepository;
import pt.sousavf.securemessaging.repository.UserRepository;
import pt.sousavf.securemessaging.repository.DeviceTokenRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class ConversationService {

    private static final Logger logger = LoggerFactory.getLogger(ConversationService.class);

    @Autowired
    private ConversationRepository conversationRepository;

    @Autowired
    private ConversationParticipantRepository participantRepository;

    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SubscriptionService subscriptionService;

    @Autowired
    private ApnsPushService apnsPushService;

    @Autowired
    private DeviceTokenRepository deviceTokenRepository;

    @Autowired(required = false)
    private ConversationRedisRepository conversationRedisRepository;

    @Autowired(required = false)
    private MessageRedisRepository messageRedisRepository;

    /**
     * Create a new conversation (only business users with premium subscription can create)
     */
    @Transactional
    public Conversation createConversation(String deviceId, int ttlHours) {
        logger.info("Creating new conversation for device: {}", deviceId);

        // Auto-create user if doesn't exist
        User user = userRepository.findByDeviceId(deviceId)
            .orElseGet(() -> {
                User newUser = new User(deviceId);
                return userRepository.save(newUser);
            });

        // Check if user is business user and has active premium subscription
        if (!user.isPremiumActive()) {
        //    throw new IllegalStateException("Only premium subscription users can create conversations");
        }

        // Calculate expiration time
        LocalDateTime expiresAt = LocalDateTime.now().plusHours(ttlHours);

        // Create and save conversation
        Conversation conversation = new Conversation(user.getId(), expiresAt);
        Conversation savedConversation = conversationRepository.save(conversation);

        // Cache in Redis
        if (conversationRedisRepository != null) {
            conversationRedisRepository.storeConversation(savedConversation);
            conversationRedisRepository.addConversationToDevice(deviceId, savedConversation);
        }

        // Track the initiator as a participant
        ConversationParticipant initiatorParticipant = new ConversationParticipant(
            savedConversation.getId(),
            deviceId,
            true // isInitiator
        );
        participantRepository.save(initiatorParticipant);
        logger.info("Conversation created: {}, initiator device: {}", savedConversation.getId(), deviceId);

        return savedConversation;
    }

    /**
     * Get a conversation by ID
     */
    public Optional<Conversation> getConversation(UUID conversationId) {
        return conversationRepository.findById(conversationId);
    }

    /**
     * Get all conversations initiated by a user
     */
    public List<Conversation> getUserConversations(String deviceId) {
        // Auto-create user if doesn't exist
        User user = userRepository.findByDeviceId(deviceId)
            .orElseGet(() -> {
                User newUser = new User(deviceId);
                return userRepository.save(newUser);
            });

        return conversationRepository.findActiveByInitiatorUserId(user.getId());
    }

    /**
     * Get all active conversations initiated by a user
     */
    public List<Conversation> getUserActiveConversations(String deviceId) {
        User user = userRepository.findByDeviceId(deviceId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));

        return conversationRepository.findActiveByInitiatorUserId(user.getId());
    }

    /**
     * Delete a conversation (only initiator can delete)
     * This marks all participants as departed and sends push notifications
     */
    @Transactional
    public void deleteConversation(UUID conversationId, String deviceId) {
        logger.info("Attempting to delete conversation: {} from device: {}", conversationId, deviceId);

        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        User user = userRepository.findByDeviceId(deviceId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));

        // Check if user is the initiator
        if (!conversation.getInitiatorUserId().equals(user.getId())) {
            throw new IllegalStateException("Only conversation initiator can delete it");
        }

        // Get all participants before marking as deleted
        List<ConversationParticipant> participants = participantRepository.findByConversationId(conversationId);
        List<String> participantDeviceIds = participants.stream()
                .map(ConversationParticipant::getDeviceId)
                .toList();

        // Mark all participants as departed
        for (ConversationParticipant participant : participants) {
            if (participant.isActive()) {
                participant.markAsDeparted();
                participantRepository.save(participant);
                logger.info("Marked participant as departed - Conversation: {}, Device: {}", conversationId, participant.getDeviceId());
            }
        }

        // Mark as deleted
        conversation.setStatus(Conversation.ConversationStatus.DELETED);
        conversationRepository.save(conversation);
        logger.info("Conversation marked as deleted: {}", conversationId);

        // Invalidate caches
        if (conversationRedisRepository != null) {
            conversationRedisRepository.invalidateConversation(conversationId);
            // Invalidate for all participant devices
            for (String participantDeviceId : participantDeviceIds) {
                conversationRedisRepository.removeConversationFromDevice(participantDeviceId, conversationId);
            }
        }
        if (messageRedisRepository != null) {
            messageRedisRepository.invalidateConversationMessages(conversationId);
        }

        // Delete all associated messages
        messageRepository.deleteByConversationId(conversationId);

        // Send deletion notification to all participants (except the initiator who is deleting it)
        logger.info("Sending deletion notification to {} participants", participantDeviceIds.size());
        apnsPushService.sendConversationDeletedPush(conversationId, participantDeviceIds, deviceId);
    }

    /**
     * Check if a conversation is active and accessible
     */
    public boolean isConversationActive(UUID conversationId) {
        return conversationRepository.isActive(conversationId);
    }

    /**
     * Check if a user can access a conversation
     * For now, any user can access any active conversation (privacy via privateKey)
     */
    public boolean canAccessConversation(UUID conversationId) {
        Optional<Conversation> conversation = conversationRepository.findById(conversationId);
        return conversation.isPresent() && conversation.get().isActive();
    }

    /**
     * Scheduled task to mark conversations as expired and notify participants
     */
    @Transactional
    public void expireConversations() {
        List<Conversation> expiredConversations = conversationRepository.findExpiredConversations();
        for (Conversation conversation : expiredConversations) {
            conversation.setStatus(Conversation.ConversationStatus.EXPIRED);
            conversationRepository.save(conversation);

            // Notify all participants that the conversation has expired
            List<ConversationParticipant> participants = participantRepository.findByConversationId(conversation.getId());
            List<String> participantDeviceIds = participants.stream()
                    .map(ConversationParticipant::getDeviceId)
                    .toList();

            logger.info("Sending expiration notification to {} participants for conversation {}",
                    participantDeviceIds.size(), conversation.getId());
            apnsPushService.sendConversationExpiredPush(conversation.getId(), participantDeviceIds);
        }
    }

    /**
     * Scheduled task to clean up deleted conversations older than 1 hour
     */
    @Transactional
    public void cleanupDeletedConversations() {
        LocalDateTime cutoffTime = LocalDateTime.now().minusHours(1);
        List<Conversation> deletedConversations = conversationRepository.findDeletedConversationsOlderThan(cutoffTime);
        conversationRepository.deleteAll(deletedConversations);
    }

    /**
     * Register a device as a participant in a conversation (when joining via QR code)
     * Only allows ONE secondary participant (creator + 1 joiner = 2 total)
     */
    @Transactional
    public void registerParticipant(UUID conversationId, String deviceId) {
        logger.info("Registering participant - Conversation: {}, Device: {}", conversationId, deviceId);

        // Check if conversation exists and is active
        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        if (!conversation.isActive()) {
            throw new IllegalStateException("Conversation is not active");
        }

        // Check if participant already exists
        Optional<ConversationParticipant> existingParticipant = participantRepository.findByConversationAndDevice(conversationId, deviceId);

        if (existingParticipant.isPresent()) {
            ConversationParticipant participant = existingParticipant.get();
            // If they were previously departed, mark them as rejoined
            if (!participant.isActive()) {
                participant.setDepartedAt(null);
                participantRepository.save(participant);
                logger.info("Participant rejoined conversation - Conversation: {}, Device: {}", conversationId, deviceId);
            }
        } else {
            // Check if link has already been consumed (another device already joined)
            boolean linkAlreadyConsumed = participantRepository.hasSecondaryParticipant(conversationId);
            if (linkAlreadyConsumed) {
                logger.warn("Conversation link already consumed - Conversation: {}", conversationId);
                throw new IllegalStateException("This conversation link has already been used. Conversations can only have 2 participants (creator and 1 joiner)");
            }

            // Add new participant and mark link as consumed
            ConversationParticipant newParticipant = new ConversationParticipant(
                conversationId,
                deviceId,
                false // not initiator
            );
            newParticipant.markLinkAsConsumed();
            participantRepository.save(newParticipant);
            logger.info("New participant added and link consumed - Conversation: {}, Device: {}", conversationId, deviceId);
        }
    }

    /**
     * Check if a device is an active participant in a conversation
     */
    public boolean isActiveParticipant(UUID conversationId, String deviceId) {
        return participantRepository.isActiveParticipant(conversationId, deviceId);
    }

    /**
     * Get active participants in a conversation
     */
    public List<ConversationParticipant> getActiveParticipants(UUID conversationId) {
        return participantRepository.findActiveParticipants(conversationId);
    }

    /**
     * Leave a conversation (mark participant as departed)
     * This allows any participant to leave without deleting the conversation
     * Used when a secondary participant wants to leave or initiator wants to leave without full deletion
     */
    @Transactional
    public void leaveConversation(UUID conversationId, String deviceId) {
        logger.info("Participant leaving conversation - Conversation: {}, Device: {}", conversationId, deviceId);

        // Check if conversation exists
        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        // Find participant
        Optional<ConversationParticipant> participantOpt = participantRepository.findByConversationAndDevice(conversationId, deviceId);

        if (participantOpt.isEmpty()) {
            throw new IllegalArgumentException("Device is not a participant in this conversation");
        }

        ConversationParticipant participant = participantOpt.get();

        // Mark as departed
        if (participant.isActive()) {
            participant.markAsDeparted();
            participantRepository.save(participant);
            logger.info("Participant marked as departed - Conversation: {}, Device: {}", conversationId, deviceId);
        }
    }
}
