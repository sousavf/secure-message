package pt.sousavf.securemessaging.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import pt.sousavf.securemessaging.entity.Message;
import pt.sousavf.securemessaging.repository.MessageRepository;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Service
public class FileProcessingService {

    private static final Logger logger = LoggerFactory.getLogger(FileProcessingService.class);
    private static final String REDIS_FILE_PREFIX = "file:upload:";
    private static final int REDIS_TTL_HOURS = 1; // Files in Redis expire after 1 hour

    @Autowired
    private RedisTemplate<String, String> redisTemplate;

    @Autowired
    private FileStorageService fileStorageService;

    @Autowired
    private MessageRepository messageRepository;

    /**
     * Store encrypted file temporarily in Redis
     * Returns the file ID for async processing
     */
    public UUID storeInCache(String encryptedContent) {
        UUID fileId = UUID.randomUUID();
        String redisKey = REDIS_FILE_PREFIX + fileId.toString();

        try {
            redisTemplate.opsForValue().set(redisKey, encryptedContent, REDIS_TTL_HOURS, TimeUnit.HOURS);
            logger.debug("Stored file in Redis cache: {}, expires in {} hours", fileId, REDIS_TTL_HOURS);
            return fileId;
        } catch (Exception e) {
            logger.error("Failed to store file in Redis: {}", fileId, e);
            throw new RuntimeException("Failed to cache file", e);
        }
    }

    /**
     * Retrieve encrypted file from Redis cache
     */
    public String getFromCache(UUID fileId) {
        String redisKey = REDIS_FILE_PREFIX + fileId.toString();
        return redisTemplate.opsForValue().get(redisKey);
    }

    /**
     * Delete file from Redis cache
     */
    public void deleteFromCache(UUID fileId) {
        String redisKey = REDIS_FILE_PREFIX + fileId.toString();
        redisTemplate.delete(redisKey);
        logger.debug("Deleted file from Redis cache: {}", fileId);
    }

    /**
     * Process file asynchronously: move from Redis to local storage and update message
     */
    @Async
    public void processFileAsync(UUID messageId, UUID fileId, LocalDateTime expiresAt) {
        try {
            logger.info("Starting async file processing - Message: {}, File: {}", messageId, fileId);

            // Get encrypted content from Redis
            String encryptedContent = getFromCache(fileId);
            if (encryptedContent == null) {
                logger.error("File not found in Redis cache: {}", fileId);
                // Mark message as failed or delete it
                markMessageAsFailed(messageId);
                return;
            }

            // Store to local filesystem
            String filePath = fileStorageService.storeFile(encryptedContent, fileId, expiresAt);

            // Update message with file path
            updateMessageFilePath(messageId, filePath);

            // Clean up Redis
            deleteFromCache(fileId);

            logger.info("File processing complete - Message: {}, Path: {}", messageId, filePath);

        } catch (IOException e) {
            logger.error("Failed to process file - Message: {}, File: {}", messageId, fileId, e);
            markMessageAsFailed(messageId);
        } catch (Exception e) {
            logger.error("Unexpected error processing file - Message: {}, File: {}", messageId, fileId, e);
            markMessageAsFailed(messageId);
        }
    }

    /**
     * Update message with the local file path
     */
    private void updateMessageFilePath(UUID messageId, String filePath) {
        try {
            Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new IllegalArgumentException("Message not found: " + messageId));

            message.setFileUrl(filePath);
            messageRepository.save(message);

            logger.debug("Updated message with file path - Message: {}, Path: {}", messageId, filePath);
        } catch (Exception e) {
            logger.error("Failed to update message file path: {}", messageId, e);
            throw e;
        }
    }

    /**
     * Mark message as failed (delete it or set error status)
     */
    private void markMessageAsFailed(UUID messageId) {
        try {
            // For now, just delete the message
            // In production, you might want to set an error status instead
            messageRepository.deleteById(messageId);
            logger.warn("Deleted failed message: {}", messageId);
        } catch (Exception e) {
            logger.error("Failed to mark message as failed: {}", messageId, e);
        }
    }

    /**
     * Get file content for download (checks filesystem, falls back to Redis)
     */
    public byte[] getFileContent(String fileUrl, UUID fileId) throws IOException {
        // First try to get from local filesystem
        if (fileUrl != null && !fileUrl.isEmpty()) {
            try {
                return fileStorageService.readFile(fileUrl);
            } catch (IOException e) {
                logger.warn("File not found in storage, checking Redis: {}", fileUrl);
            }
        }

        // Fall back to Redis if file is still being processed
        if (fileId != null) {
            String encryptedContent = getFromCache(fileId);
            if (encryptedContent != null) {
                logger.debug("Serving file from Redis cache: {}", fileId);
                return java.util.Base64.getDecoder().decode(encryptedContent);
            }
        }

        throw new IOException("File not found: " + fileUrl);
    }
}
