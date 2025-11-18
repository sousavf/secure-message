package pt.sousavf.securemessaging.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import pt.sousavf.securemessaging.entity.Conversation;
import pt.sousavf.securemessaging.entity.User;
import pt.sousavf.securemessaging.repository.ConversationRepository;
import pt.sousavf.securemessaging.repository.UserRepository;

import java.util.UUID;

@Service
public class ShareService {

    @Autowired
    private ConversationRepository conversationRepository;

    @Autowired
    private UserRepository userRepository;

    @Value("${app.share.base-url:https://app.example.com}")
    private String baseUrl;

    /**
     * Generate a share link for a conversation
     * The private key will be appended by the client in the URL fragment
     * Format: https://app.example.com/join/{conversationId}#{privateKey}
     */
    public ShareLinkResponse generateShareLink(UUID conversationId, String deviceId) {
        // Find and validate conversation
        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        // Find user
        User user = userRepository.findByDeviceId(deviceId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));

        // Verify user is the initiator and is premium
        if (!conversation.getInitiatorUserId().equals(user.getId())) {
            throw new IllegalStateException("Only conversation initiator can generate share links");
        }

        if (!user.isPremiumActive()) {
        //    throw new IllegalStateException("Only premium users can share conversations");
        }

        // Verify conversation is still active
        if (!conversation.isActive()) {
            throw new IllegalStateException("Conversation is no longer active");
        }

        // Generate share URL (client will append privateKey in fragment)
        String shareUrl = String.format("%s/join/%s", baseUrl, conversationId);

        return new ShareLinkResponse(
            conversationId.toString(),
            shareUrl,
            conversation.getExpiresAt()
        );
    }

    /**
     * Validate that a conversation is accessible for joining
     * The actual access control is done via privateKey (client-side)
     */
    public boolean isConversationAccessible(UUID conversationId) {
        return conversationRepository.findById(conversationId)
            .map(Conversation::isActive)
            .orElse(false);
    }

    /**
     * Response DTO for share link generation
     */
    public static class ShareLinkResponse {
        private final String conversationId;
        private final String shareUrl;
        private final java.time.LocalDateTime expiresAt;

        public ShareLinkResponse(String conversationId, String shareUrl, java.time.LocalDateTime expiresAt) {
            this.conversationId = conversationId;
            this.shareUrl = shareUrl;
            this.expiresAt = expiresAt;
        }

        public String getConversationId() {
            return conversationId;
        }

        public String getShareUrl() {
            return shareUrl;
        }

        public java.time.LocalDateTime getExpiresAt() {
            return expiresAt;
        }
    }
}
