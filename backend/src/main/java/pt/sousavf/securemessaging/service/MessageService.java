package pt.sousavf.securemessaging.service;

import pt.sousavf.securemessaging.dto.CreateMessageRequest;
import pt.sousavf.securemessaging.dto.MessageResponse;
import pt.sousavf.securemessaging.dto.StatsResponse;
import pt.sousavf.securemessaging.entity.Conversation;
import pt.sousavf.securemessaging.entity.Message;
import pt.sousavf.securemessaging.repository.ConversationRepository;
import pt.sousavf.securemessaging.repository.MessageRepository;
import pt.sousavf.securemessaging.repository.MessageRedisRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@Transactional
public class MessageService {

    private static final Logger logger = LoggerFactory.getLogger(MessageService.class);

    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private ConversationRepository conversationRepository;

    @Autowired
    private SubscriptionService subscriptionService;

    @Autowired(required = false)
    private MessageRedisRepository messageRedisRepository;

    @Autowired(required = false)
    private ConversationService conversationService;

    @Autowired(required = false)
    private ApnsPushService apnsPushService;

    @Value("${app.message.default-ttl-hours:24}")
    private int defaultTtlHours;

    public MessageResponse createMessage(CreateMessageRequest request) {
        return createMessage(request, null);
    }

    public MessageResponse createMessage(CreateMessageRequest request, String senderDeviceId) {
        logger.info("Creating new message");
        
        // Check message size limits if sender device ID is provided
        if (senderDeviceId != null) {
            long maxSize = subscriptionService.getMaxMessageSize(senderDeviceId);
            long messageSize = estimateMessageSize(request);
            
            if (messageSize > maxSize) {
                throw new IllegalArgumentException(
                    String.format("Message size (%d bytes) exceeds limit (%d bytes). Upgrade to premium for 10MB messages.", 
                                messageSize, maxSize));
            }
        }
        
        LocalDateTime expiresAt = LocalDateTime.now().plusHours(defaultTtlHours);
        
        Message message = new Message(
            request.getCiphertext(),
            request.getNonce(),
            request.getTag(),
            expiresAt
        );
        
        if (senderDeviceId != null) {
            message.setSenderDeviceId(senderDeviceId);
        }
        
        Message savedMessage = messageRepository.save(message);
        logger.info("Message created with ID: {}, size: {} bytes", savedMessage.getId(), estimateMessageSize(request));
        
        return MessageResponse.createResponse(savedMessage.getId());
    }

    private long estimateMessageSize(CreateMessageRequest request) {
        // Rough estimation based on the ciphertext, nonce, and tag sizes
        long size = 0;
        if (request.getCiphertext() != null) {
            size += request.getCiphertext().length();
        }
        if (request.getNonce() != null) {
            size += request.getNonce().length();
        }
        if (request.getTag() != null) {
            size += request.getTag().length();
        }
        return size;
    }

    @Transactional
    public Optional<MessageResponse> retrieveMessage(UUID messageId) {
        logger.info("Attempting to retrieve message with ID: {}", messageId);
        
        Optional<Message> messageOpt = messageRepository.findAvailableMessage(messageId, LocalDateTime.now());
        
        if (messageOpt.isEmpty()) {
            logger.warn("Message not found or already consumed/expired: {}", messageId);
            return Optional.empty();
        }
        
        Message message = messageOpt.get();
        
        if (message.isExpired()) {
            logger.warn("Message is expired: {}", messageId);
            return Optional.empty();
        }
        
        message.markAsConsumed();
        messageRepository.save(message);
        
        logger.info("Message retrieved and marked as consumed: {}", messageId);
        return Optional.of(MessageResponse.fromMessage(message));
    }

    public boolean isMessageConsumed(UUID messageId) {
        return messageRepository.findById(messageId)
            .map(Message::isConsumed)
            .orElse(true);
    }

    public StatsResponse getDailyStats(LocalDate date) {
        LocalDateTime dateTime = date.atStartOfDay();
        LocalDateTime now = LocalDateTime.now();
        
        long messagesCreated = messageRepository.countMessagesCreatedOnDate(dateTime);
        long messagesRead = messageRepository.countMessagesReadOnDate(dateTime);
        long activeMessages = messageRepository.countActiveMessages(now);
        long totalConsumedMessages = messageRepository.countConsumedMessages();
        
        return new StatsResponse(date, messagesCreated, messagesRead, activeMessages, totalConsumedMessages);
    }

    public StatsResponse getTodayStats() {
        return getDailyStats(LocalDate.now());
    }

    @Scheduled(fixedRateString = "${app.message.cleanup-interval-minutes:60}000")
    public void cleanupExpiredMessages() {
        logger.info("Starting cleanup of expired messages");

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime consumedThreshold = now.minusHours(1);

        int expiredDeleted = messageRepository.deleteExpiredMessages(now);
        int consumedDeleted = messageRepository.deleteConsumedMessages(consumedThreshold);
        int conversationMessagesDeleted = messageRepository.deleteMessagesFromExpiredConversations(now);

        if (expiredDeleted > 0 || consumedDeleted > 0 || conversationMessagesDeleted > 0) {
            logger.info("Cleanup completed: {} expired standalone messages deleted, {} consumed standalone messages deleted, {} messages from expired conversations deleted",
                       expiredDeleted, consumedDeleted, conversationMessagesDeleted);
        }

        // Also clean up conversations
        if (conversationService != null) {
            try {
                conversationService.expireConversations();
                conversationService.cleanupDeletedConversations();
            } catch (Exception e) {
                logger.error("Error cleaning up conversations", e);
            }
        }
    }

    /**
     * Create a message in a conversation
     */
    public MessageResponse createConversationMessage(UUID conversationId, CreateMessageRequest request, String senderDeviceId) {
        logger.info("Creating message in conversation: {}", conversationId);

        // Validate conversation exists and is active
        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        if (!conversation.isActive()) {
            throw new IllegalStateException("Conversation is no longer active");
        }

        // Check message size limits if sender device ID is provided
        if (senderDeviceId != null) {
            long maxSize = subscriptionService.getMaxMessageSize(senderDeviceId);
            long messageSize = estimateMessageSize(request);

            if (messageSize > maxSize) {
                throw new IllegalArgumentException(
                    String.format("Message size (%d bytes) exceeds limit (%d bytes). Upgrade to premium for 10MB messages.",
                        messageSize, maxSize));
            }
        }

        LocalDateTime expiresAt = LocalDateTime.now().plusHours(defaultTtlHours);

        Message message = new Message(
            request.getCiphertext(),
            request.getNonce(),
            request.getTag(),
            expiresAt
        );
        message.setConversationId(conversationId);

        if (senderDeviceId != null) {
            message.setSenderDeviceId(senderDeviceId);
        }

        Message savedMessage = messageRepository.save(message);
        logger.info("Conversation message created with ID: {}, conversation: {}", savedMessage.getId(), conversationId);

        // Invalidate cached messages for this conversation (new message added)
        if (messageRedisRepository != null) {
            messageRedisRepository.invalidateConversationMessages(conversationId);
            messageRedisRepository.storeMessage(savedMessage);  // Cache the new message
        }

        // Send push notification to other participants
        if (apnsPushService != null && conversationService != null) {
            try {
                sendPushToParticipants(conversationId, senderDeviceId);
            } catch (Exception e) {
                logger.error("Error sending push notification for conversation {}", conversationId, e);
                // Don't fail message creation if push fails - it's asynchronous
            }
        }

        return MessageResponse.fromMessage(savedMessage);
    }

    /**
     * Get all active messages in a conversation
     * Tries to retrieve from Redis cache first, falls back to database if not cached
     */
    public List<MessageResponse> getConversationMessages(UUID conversationId) {
        logger.info("Retrieving messages for conversation: {}", conversationId);

        // Validate conversation exists and is active
        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        if (!conversation.isActive()) {
            throw new IllegalStateException("Conversation is no longer active");
        }

        // Try to get from Redis cache first
        if (messageRedisRepository != null && messageRedisRepository.hasConversationMessages(conversationId)) {
            List<Message> cachedMessages = messageRedisRepository.getConversationMessages(conversationId);
            if (!cachedMessages.isEmpty()) {
                logger.info("Retrieved {} cached messages for conversation: {}", cachedMessages.size(), conversationId);
                return cachedMessages.stream()
                    .map(MessageResponse::fromMessage)
                    .collect(Collectors.toList());
            }
        }

        // Fall back to database
        List<Message> messages = messageRepository.findActiveByConversationId(conversationId);
        logger.info("Found {} active messages for conversation: {} (current time: {})",
            messages.size(), conversationId, LocalDateTime.now());

        for (Message msg : messages) {
            logger.debug("Message ID: {}, expiresAt: {}, isExpired: {}",
                msg.getId(), msg.getExpiresAt(), msg.isExpired());
        }

        // Cache the result in Redis
        if (messageRedisRepository != null && !messages.isEmpty()) {
            messageRedisRepository.storeConversationMessages(conversationId, messages);
        }

        return messages.stream()
            .map(MessageResponse::fromMessage)
            .collect(Collectors.toList());
    }

    /**
     * Get messages in a conversation created since a specific timestamp (for polling)
     */
    public List<MessageResponse> getConversationMessagesSince(UUID conversationId, LocalDateTime since) {
        logger.info("Retrieving messages for conversation: {} since: {}", conversationId, since);

        // Validate conversation exists and is active
        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        if (!conversation.isActive()) {
            throw new IllegalStateException("Conversation is no longer active");
        }

        List<Message> messages = messageRepository.findActiveByConversationIdAndCreatedAfter(conversationId, since);
        logger.info("Found {} new messages for conversation: {} since: {}",
            messages.size(), conversationId, since);

        return messages.stream()
            .map(MessageResponse::fromMessage)
            .collect(Collectors.toList());
    }

    /**
     * Retrieve and consume a message from a conversation
     */
    @Transactional
    public Optional<MessageResponse> retrieveConversationMessage(UUID conversationId, UUID messageId) {
        logger.info("Retrieving message from conversation: {} - Message: {}", conversationId, messageId);

        // Validate conversation exists and is active
        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        if (!conversation.isActive()) {
            throw new IllegalStateException("Conversation is no longer active");
        }

        Optional<Message> messageOpt = messageRepository.findById(messageId);

        if (messageOpt.isEmpty()) {
            logger.warn("Message not found: {}", messageId);
            return Optional.empty();
        }

        Message message = messageOpt.get();

        // Verify message belongs to this conversation
        if (!conversationId.equals(message.getConversationId())) {
            logger.warn("Message does not belong to conversation: {}", conversationId);
            return Optional.empty();
        }

        if (message.isConsumed() || message.isExpired()) {
            logger.warn("Message already consumed or expired: {}", messageId);
            return Optional.empty();
        }

        message.markAsConsumed();
        messageRepository.save(message);

        logger.info("Conversation message retrieved and marked as consumed: {}", messageId);
        return Optional.of(MessageResponse.fromMessage(message));
    }

    /**
     * Send push notifications to all participants in a conversation except the sender
     */
    private void sendPushToParticipants(UUID conversationId, String senderDeviceId) {
        try {
            // Get all active participants in the conversation
            List<String> participantDeviceIds = conversationService
                    .getActiveParticipants(conversationId)
                    .stream()
                    .map(participant -> participant.getDeviceId())
                    .toList();

            logger.debug("Sending push to {} participants for conversation {}", participantDeviceIds.size(), conversationId);

            // Send silent push to each participant (except sender)
            apnsPushService.sendPushToConversationParticipants(conversationId, participantDeviceIds, senderDeviceId);

        } catch (Exception e) {
            logger.error("Error sending push to participants for conversation {}", conversationId, e);
        }
    }
}