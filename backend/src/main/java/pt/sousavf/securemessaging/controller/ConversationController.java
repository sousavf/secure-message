package pt.sousavf.securemessaging.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pt.sousavf.securemessaging.dto.CreateConversationRequest;
import pt.sousavf.securemessaging.entity.Conversation;
import pt.sousavf.securemessaging.service.ConversationService;
import pt.sousavf.securemessaging.service.ShareService;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/conversations")
public class ConversationController {

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
}
