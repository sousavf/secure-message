package pt.sousavf.securemessaging.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pt.sousavf.securemessaging.dto.CreateConversationRequest;
import pt.sousavf.securemessaging.dto.ParticipantStatusResponse;
import pt.sousavf.securemessaging.entity.Conversation;
import pt.sousavf.securemessaging.entity.ConversationParticipant;
import pt.sousavf.securemessaging.service.ConversationService;
import pt.sousavf.securemessaging.service.ShareService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/conversations")
public class ConversationController {

    private static final Logger logger = LoggerFactory.getLogger(ConversationController.class);

    @Autowired
    private ConversationService conversationService;

    @Autowired
    private ShareService shareService;

    /**
     * Create a new privileged conversation
     * Only PREMIUM_ACTIVE users can create conversations
     */
    @PostMapping
    public ResponseEntity<?> createConversation(
            @RequestHeader("X-Device-ID") String deviceId,
            @RequestBody CreateConversationRequest request) {
        try {
            Conversation conversation = conversationService.createConversation(
                deviceId,
                request.getTtlHours() != null ? request.getTtlHours() : 48
            );

            return ResponseEntity.status(HttpStatus.CREATED)
                .body(ConversationResponse.fromEntity(conversation));
        } catch (IllegalStateException e) {
            return ResponseEntity.status(HttpStatus.PAYMENT_REQUIRED)
                .body(new ErrorResponse("Only premium users can create conversations: " + e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(new ErrorResponse(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error creating conversation: " + e.getMessage()));
        }
    }

    /**
     * Get a specific conversation by ID
     */
    @GetMapping("/{conversationId}")
    public ResponseEntity<?> getConversation(
            @PathVariable UUID conversationId) {
        try {
            var conversation = conversationService.getConversation(conversationId);
            if (conversation.isPresent()) {
                return ResponseEntity.ok(ConversationResponse.fromEntity(conversation.get()));
            } else {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(new ErrorResponse("Conversation not found"));
            }
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error retrieving conversation: " + e.getMessage()));
        }
    }

    /**
     * List all conversations initiated by the user
     */
    @GetMapping
    public ResponseEntity<?> listConversations(
            @RequestHeader("X-Device-ID") String deviceId) {
        try {
            List<Conversation> conversations = conversationService.getUserConversations(deviceId);
            return ResponseEntity.ok(conversations.stream()
                .map(ConversationResponse::fromEntity)
                .toList());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(new ErrorResponse(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error listing conversations: " + e.getMessage()));
        }
    }

    /**
     * Delete a conversation
     * Only the initiator can delete
     */
    @DeleteMapping("/{conversationId}")
    public ResponseEntity<?> deleteConversation(
            @PathVariable UUID conversationId,
            @RequestHeader("X-Device-ID") String deviceId) {
        try {
            conversationService.deleteConversation(conversationId, deviceId);
            return ResponseEntity.noContent().build();
        } catch (IllegalStateException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(new ErrorResponse(e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error deleting conversation: " + e.getMessage()));
        }
    }

    /**
     * Generate a share link for a conversation
     * Only the initiator can generate share links, and must have active premium subscription
     */
    @PostMapping("/{conversationId}/share")
    public ResponseEntity<?> generateShareLink(
            @PathVariable UUID conversationId,
            @RequestHeader("X-Device-ID") String deviceId) {
        try {
            ShareService.ShareLinkResponse shareLinkResponse = shareService.generateShareLink(conversationId, deviceId);
            return ResponseEntity.ok(shareLinkResponse);
        } catch (IllegalStateException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(new ErrorResponse(e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error generating share link: " + e.getMessage()));
        }
    }

    /**
     * Validate if a conversation is accessible
     */
    @GetMapping("/{conversationId}/accessible")
    public ResponseEntity<?> isConversationAccessible(
            @PathVariable UUID conversationId) {
        try {
            boolean accessible = shareService.isConversationAccessible(conversationId);
            return ResponseEntity.ok(new AccessibilityResponse(conversationId.toString(), accessible));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error checking conversation accessibility: " + e.getMessage()));
        }
    }

    /**
     * Register a device as a participant when joining a conversation via QR code
     */
    @PostMapping("/{conversationId}/join")
    public ResponseEntity<?> joinConversation(
            @PathVariable UUID conversationId,
            @RequestHeader("X-Device-ID") String deviceId) {
        try {
            logger.info("Device joining conversation - Conversation: {}, Device: {}", conversationId, deviceId);
            conversationService.registerParticipant(conversationId, deviceId);
            return ResponseEntity.ok(new ErrorResponse("Successfully joined conversation"));
        } catch (IllegalStateException e) {
            logger.warn("Cannot join conversation: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new ErrorResponse(e.getMessage()));
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid conversation: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse(e.getMessage()));
        } catch (Exception e) {
            logger.error("Error joining conversation", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error joining conversation: " + e.getMessage()));
        }
    }

    /**
     * Get status of all participants in a conversation
     */
    @GetMapping("/{conversationId}/participants")
    public ResponseEntity<?> getParticipants(
            @PathVariable UUID conversationId) {
        try {
            logger.info("Fetching participants for conversation: {}", conversationId);
            List<ConversationParticipant> participants = conversationService.getActiveParticipants(conversationId);

            List<ParticipantStatusResponse> responses = participants.stream()
                .map(p -> new ParticipantStatusResponse(
                    p.getConversationId(),
                    p.getDeviceId(),
                    p.isInitiator(),
                    p.isActive(),
                    p.getJoinedAt(),
                    p.getDepartedAt()
                ))
                .toList();

            return ResponseEntity.ok(responses);
        } catch (Exception e) {
            logger.error("Error fetching participants", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error fetching participants: " + e.getMessage()));
        }
    }

    /**
     * Check if a specific device is an active participant
     */
    @GetMapping("/{conversationId}/participants/{deviceId}/status")
    public ResponseEntity<?> getParticipantStatus(
            @PathVariable UUID conversationId,
            @PathVariable String deviceId) {
        try {
            logger.info("Checking participant status - Conversation: {}, Device: {}", conversationId, deviceId);
            boolean isActive = conversationService.isActiveParticipant(conversationId, deviceId);
            return ResponseEntity.ok(new ParticipantStatusSimpleResponse(conversationId, deviceId, isActive));
        } catch (Exception e) {
            logger.error("Error checking participant status", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error checking participant status: " + e.getMessage()));
        }
    }

    /**
     * Leave a conversation (for any participant, including initiator)
     * Marks the participant as departed but does not delete the conversation
     */
    @PostMapping("/{conversationId}/leave")
    public ResponseEntity<?> leaveConversation(
            @PathVariable UUID conversationId,
            @RequestHeader("X-Device-ID") String deviceId) {
        try {
            logger.info("Device leaving conversation - Conversation: {}, Device: {}", conversationId, deviceId);
            conversationService.leaveConversation(conversationId, deviceId);
            return ResponseEntity.noContent().build();
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid request: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse(e.getMessage()));
        } catch (Exception e) {
            logger.error("Error leaving conversation", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error leaving conversation: " + e.getMessage()));
        }
    }

    // Response DTOs

    public static class ConversationResponse {
        private final String id;
        private final String initiatorUserId;
        private final String status;
        private final String expiresAt;
        private final String createdAt;

        public ConversationResponse(String id, String initiatorUserId, String status, String expiresAt, String createdAt) {
            this.id = id;
            this.initiatorUserId = initiatorUserId;
            this.status = status;
            this.expiresAt = expiresAt;
            this.createdAt = createdAt;
        }

        public static ConversationResponse fromEntity(Conversation conversation) {
            return new ConversationResponse(
                conversation.getId().toString(),
                conversation.getInitiatorUserId().toString(),
                conversation.getStatus().toString(),
                conversation.getExpiresAt().toString(),
                conversation.getCreatedAt().toString()
            );
        }

        public String getId() {
            return id;
        }

        public String getInitiatorUserId() {
            return initiatorUserId;
        }

        public String getStatus() {
            return status;
        }

        public String getExpiresAt() {
            return expiresAt;
        }

        public String getCreatedAt() {
            return createdAt;
        }
    }

    public static class AccessibilityResponse {
        private final String conversationId;
        private final boolean accessible;

        public AccessibilityResponse(String conversationId, boolean accessible) {
            this.conversationId = conversationId;
            this.accessible = accessible;
        }

        public String getConversationId() {
            return conversationId;
        }

        public boolean isAccessible() {
            return accessible;
        }
    }

    public static class ErrorResponse {
        private final String message;

        public ErrorResponse(String message) {
            this.message = message;
        }

        public String getMessage() {
            return message;
        }
    }

    public static class ParticipantStatusSimpleResponse {
        private final UUID conversationId;
        private final String deviceId;
        private final boolean isActive;

        public ParticipantStatusSimpleResponse(UUID conversationId, String deviceId, boolean isActive) {
            this.conversationId = conversationId;
            this.deviceId = deviceId;
            this.isActive = isActive;
        }

        public UUID getConversationId() {
            return conversationId;
        }

        public String getDeviceId() {
            return deviceId;
        }

        public boolean isActive() {
            return isActive;
        }
    }
}
