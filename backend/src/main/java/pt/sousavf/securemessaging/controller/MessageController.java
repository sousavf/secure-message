package pt.sousavf.securemessaging.controller;

import pt.sousavf.securemessaging.dto.CreateMessageRequest;
import pt.sousavf.securemessaging.dto.MessageResponse;
import pt.sousavf.securemessaging.service.MessageService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/")
@CrossOrigin(origins = {"http://localhost:3000", "https://localhost:3000"})
public class MessageController {

    private static final Logger logger = LoggerFactory.getLogger(MessageController.class);

    private final MessageService messageService;

    public MessageController(MessageService messageService) {
        this.messageService = messageService;
    }

    @PostMapping
    public ResponseEntity<MessageResponse> createMessage(
            @Valid @RequestBody CreateMessageRequest request,
            @RequestHeader(value = "X-Device-ID", required = false) String deviceId) {
        try {
            logger.info("Received request to create message from device: {}", deviceId);
            MessageResponse response = messageService.createMessage(request, deviceId);
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (IllegalArgumentException e) {
            logger.warn("Message size limit exceeded: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE)
                               .header("X-Error-Message", e.getMessage())
                               .build();
        } catch (Exception e) {
            logger.error("Error creating message", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<MessageResponse> getMessage(@PathVariable UUID id) {
        try {
            logger.info("Received request to retrieve message: {}", id);
            
            if (messageService.isMessageConsumed(id)) {
                logger.warn("Message already consumed: {}", id);
                return ResponseEntity.status(HttpStatus.GONE).build();
            }
            
            Optional<MessageResponse> message = messageService.retrieveMessage(id);
            
            if (message.isPresent()) {
                return ResponseEntity.ok(message.get());
            } else {
                return ResponseEntity.status(HttpStatus.GONE).build();
            }
        } catch (Exception e) {
            logger.error("Error retrieving message: {}", id, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleInvalidUUID(IllegalArgumentException e) {
        logger.warn("Invalid UUID provided: {}", e.getMessage());
        return ResponseEntity.badRequest().body("Invalid message ID format");
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<String> handleGeneralException(Exception e) {
        logger.error("Unexpected error in MessageController", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                           .body("An unexpected error occurred");
    }

    // Conversation-scoped message endpoints

    /**
     * Create a message in a conversation
     */
    @PostMapping("/api/conversations/{conversationId}/messages")
    public ResponseEntity<?> createConversationMessage(
            @PathVariable UUID conversationId,
            @Valid @RequestBody CreateMessageRequest request,
            @RequestHeader(value = "X-Device-ID", required = false) String deviceId) {
        try {
            logger.info("Received request to create message in conversation: {} from device: {}", conversationId, deviceId);
            MessageResponse response = messageService.createConversationMessage(conversationId, request, deviceId);
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid request: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(new ErrorMessage(e.getMessage()));
        } catch (IllegalStateException e) {
            logger.warn("State error: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new ErrorMessage(e.getMessage()));
        } catch (Exception e) {
            logger.error("Error creating conversation message", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorMessage("Error creating message"));
        }
    }

    /**
     * Get all messages in a conversation, optionally filtered by creation time
     */
    @GetMapping("/api/conversations/{conversationId}/messages")
    public ResponseEntity<?> getConversationMessages(
            @PathVariable UUID conversationId,
            @RequestParam(required = false) String since) {
        try {
            logger.info("Received request to retrieve messages from conversation: {} since: {}", conversationId, since);

            List<MessageResponse> messages;

            // If 'since' parameter is provided, fetch only messages created after that time
            if (since != null && !since.isEmpty()) {
                try {
                    LocalDateTime sinceTime = LocalDateTime.parse(since);
                    messages = messageService.getConversationMessagesSince(conversationId, sinceTime);
                    logger.info("Retrieved {} incremental messages since {}", messages.size(), since);
                } catch (Exception e) {
                    logger.warn("Invalid 'since' parameter format: {}", since);
                    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(new ErrorMessage("Invalid 'since' parameter. Use ISO-8601 format: 2025-11-19T18:30:00"));
                }
            } else {
                // If no 'since' parameter, fetch all messages
                messages = messageService.getConversationMessages(conversationId);
                logger.info("Retrieved {} total messages", messages.size());
            }

            return ResponseEntity.ok(messages);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid request: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(new ErrorMessage(e.getMessage()));
        } catch (IllegalStateException e) {
            logger.warn("State error: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new ErrorMessage(e.getMessage()));
        } catch (Exception e) {
            logger.error("Error retrieving conversation messages", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorMessage("Error retrieving messages"));
        }
    }

    /**
     * Retrieve and consume a specific message from a conversation
     */
    @GetMapping("/api/conversations/{conversationId}/messages/{messageId}")
    public ResponseEntity<?> getConversationMessage(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId) {
        try {
            logger.info("Received request to retrieve message: {} from conversation: {}", messageId, conversationId);

            Optional<MessageResponse> message = messageService.retrieveConversationMessage(conversationId, messageId);

            if (message.isPresent()) {
                return ResponseEntity.ok(message.get());
            } else {
                return ResponseEntity.status(HttpStatus.GONE).build();
            }
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid request: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(new ErrorMessage(e.getMessage()));
        } catch (IllegalStateException e) {
            logger.warn("State error: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new ErrorMessage(e.getMessage()));
        } catch (Exception e) {
            logger.error("Error retrieving conversation message: {}", messageId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorMessage("Error retrieving message"));
        }
    }

    // Helper class for error messages
    public static class ErrorMessage {
        private final String message;

        public ErrorMessage(String message) {
            this.message = message;
        }

        public String getMessage() {
            return message;
        }
    }
}