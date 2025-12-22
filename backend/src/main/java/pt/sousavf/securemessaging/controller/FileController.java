package pt.sousavf.securemessaging.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pt.sousavf.securemessaging.dto.FileUploadRequest;
import pt.sousavf.securemessaging.dto.FileUploadResponse;
import pt.sousavf.securemessaging.entity.Conversation;
import pt.sousavf.securemessaging.entity.Message;
import pt.sousavf.securemessaging.service.ConversationService;
import pt.sousavf.securemessaging.service.FileProcessingService;
import pt.sousavf.securemessaging.repository.MessageRepository;

import java.io.IOException;
import java.util.UUID;

@RestController
@RequestMapping("/api")
public class FileController {

    private static final Logger logger = LoggerFactory.getLogger(FileController.class);
    private static final int MAX_FILE_SIZE = 10_485_760; // 10MB

    @Autowired
    private ConversationService conversationService;

    @Autowired
    private FileProcessingService fileProcessingService;

    @Autowired
    private MessageRepository messageRepository;

    /**
     * Upload an encrypted file to a conversation
     * Flow:
     * 1. Validate request and file size
     * 2. Store encrypted file in Redis cache
     * 3. Create message record with file metadata
     * 4. Trigger async processing to move file to local storage
     * 5. Return immediately with file ID
     */
    @PostMapping("/conversations/{conversationId}/files")
    public ResponseEntity<?> uploadFile(
            @PathVariable UUID conversationId,
            @RequestHeader("X-Device-ID") String deviceId,
            @RequestBody FileUploadRequest request) {
        try {
            logger.info("File upload - Conversation: {}, Device: {}, File: {}, Size: {} bytes",
                conversationId, deviceId, request.getFileName(), request.getFileSize());

            // Validate file size
            if (request.getFileSize() > MAX_FILE_SIZE) {
                return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE)
                    .body(new ErrorResponse("File size exceeds 10MB limit"));
            }

            // Verify conversation exists and user is a participant
            var conversation = conversationService.getConversation(conversationId);
            if (conversation.isEmpty() || conversation.get().isDeleted()) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(new ErrorResponse("Conversation not found"));
            }

            Conversation conv = conversation.get();

            // Store encrypted file in Redis cache first
            UUID fileId = fileProcessingService.storeInCache(request.getCiphertext());

            // Create message record immediately
            Message fileMessage = new Message();
            fileMessage.setConversationId(conversationId);
            fileMessage.setSenderDeviceId(deviceId);

            // Determine message type based on MIME type
            Message.MessageType messageType = Message.MessageType.FILE;
            if (request.getMimeType() != null && request.getMimeType().startsWith("image/")) {
                messageType = Message.MessageType.IMAGE;
            }
            fileMessage.setMessageType(messageType);

            // Store minimal ciphertext placeholder (actual file is in Redis/storage)
            fileMessage.setCiphertext("FILE:" + fileId.toString());
            fileMessage.setNonce(request.getNonce());
            fileMessage.setTag(request.getTag());
            fileMessage.setFileName(request.getFileName());
            fileMessage.setFileSize(request.getFileSize());
            fileMessage.setFileMimeType(request.getMimeType());
            fileMessage.setFileUrl(null); // Will be set by async processor
            fileMessage.setExpiresAt(conv.getExpiresAt());

            Message savedMessage = conversationService.saveMessage(fileMessage);

            logger.info("File message created - Message ID: {}, File ID: {}", savedMessage.getId(), fileId);

            // Trigger async processing to move file from Redis to local storage
            fileProcessingService.processFileAsync(savedMessage.getId(), fileId, conv.getExpiresAt());

            // Return response immediately
            FileUploadResponse response = new FileUploadResponse(
                savedMessage.getId().toString(),
                "/api/files/" + fileId.toString(),
                request.getFileName(),
                request.getFileSize(),
                request.getMimeType()
            );

            return ResponseEntity.status(HttpStatus.CREATED).body(response);

        } catch (Exception e) {
            logger.error("Error uploading file", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error uploading file: " + e.getMessage()));
        }
    }

    /**
     * Download a file by file ID
     * Returns the encrypted file content as binary data
     */
    @GetMapping("/files/{fileId}")
    public ResponseEntity<?> downloadFile(@PathVariable UUID fileId) {
        try {
            logger.debug("File download request: {}", fileId);

            // Find message by file ID (stored in ciphertext as "FILE:{fileId}")
            Message message = messageRepository.findAll().stream()
                .filter(m -> m.getMessageType() == Message.MessageType.FILE || m.getMessageType() == Message.MessageType.IMAGE)
                .filter(m -> m.getCiphertext() != null && m.getCiphertext().contains(fileId.toString()))
                .findFirst()
                .orElse(null);

            if (message == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(new ErrorResponse("File not found"));
            }

            // Check if message is expired
            if (message.isExpired()) {
                return ResponseEntity.status(HttpStatus.GONE)
                    .body(new ErrorResponse("File has expired"));
            }

            // Get file content (from filesystem or Redis)
            byte[] fileContent = fileProcessingService.getFileContent(message.getFileUrl(), fileId);

            // Return file as binary data
            return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(message.getFileMimeType()))
                .header("Content-Disposition", "attachment; filename=\"" + message.getFileName() + "\"")
                .body(fileContent);

        } catch (IOException e) {
            logger.error("File not found: {}", fileId, e);
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse("File not found or expired"));
        } catch (Exception e) {
            logger.error("Error downloading file: {}", fileId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("Error downloading file: " + e.getMessage()));
        }
    }

    public static class ErrorResponse {
        private String message;

        public ErrorResponse() {
        }

        public ErrorResponse(String message) {
            this.message = message;
        }

        public String getMessage() {
            return message;
        }
    }
}
