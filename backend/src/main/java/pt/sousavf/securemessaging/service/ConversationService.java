package pt.sousavf.securemessaging.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pt.sousavf.securemessaging.entity.Conversation;
import pt.sousavf.securemessaging.entity.User;
import pt.sousavf.securemessaging.repository.ConversationRepository;
import pt.sousavf.securemessaging.repository.MessageRepository;
import pt.sousavf.securemessaging.repository.UserRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class ConversationService {

    @Autowired
    private ConversationRepository conversationRepository;

    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SubscriptionService subscriptionService;

    /**
     * Create a new conversation (only business users with premium subscription can create)
     */
    @Transactional
    public Conversation createConversation(String deviceId, int ttlHours) {
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
        return conversationRepository.save(conversation);
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
     */
    @Transactional
    public void deleteConversation(UUID conversationId, String deviceId) {
        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        User user = userRepository.findByDeviceId(deviceId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));

        // Check if user is the initiator
        if (!conversation.getInitiatorUserId().equals(user.getId())) {
            throw new IllegalStateException("Only conversation initiator can delete it");
        }

        // Mark as deleted
        conversation.setStatus(Conversation.ConversationStatus.DELETED);
        conversationRepository.save(conversation);

        // Delete all associated messages
        messageRepository.deleteByConversationId(conversationId);
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
     * Scheduled task to mark conversations as expired
     */
    @Transactional
    public void expireConversations() {
        List<Conversation> expiredConversations = conversationRepository.findExpiredConversations();
        for (Conversation conversation : expiredConversations) {
            conversation.setStatus(Conversation.ConversationStatus.EXPIRED);
            conversationRepository.save(conversation);
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
}
