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

import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/messages")
@CrossOrigin(origins = {"http://localhost:3000", "https://localhost:3000"})
public class MessageController {

    private static final Logger logger = LoggerFactory.getLogger(MessageController.class);

    private final MessageService messageService;

    public MessageController(MessageService messageService) {
        this.messageService = messageService;
    }

    @PostMapping
    public ResponseEntity<MessageResponse> createMessage(@Valid @RequestBody CreateMessageRequest request) {
        try {
            logger.info("Received request to create message");
            MessageResponse response = messageService.createMessage(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
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
}