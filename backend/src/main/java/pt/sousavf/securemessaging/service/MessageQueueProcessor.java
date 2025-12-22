package pt.sousavf.securemessaging.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import pt.sousavf.securemessaging.dto.BufferedMessage;
import pt.sousavf.securemessaging.entity.Conversation;
import pt.sousavf.securemessaging.entity.Message;
import pt.sousavf.securemessaging.repository.MessageRepository;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Map;
import java.util.UUID;

/**
 * Async processor that consumes messages from Redis queue and saves to PostgreSQL
 * Runs every 100ms to process pending messages
 */
@Service
@EnableScheduling
public class MessageQueueProcessor {

    private static final Logger logger = LoggerFactory.getLogger(MessageQueueProcessor.class);

    @Autowired
    private MessageQueueService queueService;

    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private ConversationService conversationService;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    /**
     * Process messages from Redis queue every 100ms
     */
    @Scheduled(fixedDelay = 100)
    public void processMessageQueue() {
        int processed = 0;

        // Process up to 100 messages per batch
        while (processed < 100) {
            BufferedMessage buffered = queueService.popMessage();
            if (buffered == null) break; // Queue empty

            try {
                // Create message entity
                Message message = new Message();
                message.setCiphertext(buffered.getCiphertext());
                message.setNonce(buffered.getNonce());
                message.setTag(buffered.getTag());
                message.setMessageType(buffered.getMessageType());
                message.setConversationId(buffered.getConversationId());
                message.setSenderDeviceId(buffered.getDeviceId());

                // Set file metadata if present
                if (buffered.getFileName() != null) {
                    message.setFileName(buffered.getFileName());
                    message.setFileSize(buffered.getFileSize());
                    message.setFileMimeType(buffered.getFileMimeType());
                }

                // Get expiration from conversation
                Conversation conv = conversationService.getConversation(
                    buffered.getConversationId()
                ).orElseThrow(() -> new RuntimeException("Conversation not found"));
                message.setExpiresAt(conv.getExpiresAt());

                // Save to database
                Message saved = messageRepository.save(message);

                // Notify sender: MESSAGE_DELIVERED
                notifyMessageDelivered(buffered.getDeviceId(), buffered.getServerId(), saved.getId());

                // Notify recipients: NEW_MESSAGE
                notifyNewMessage(buffered.getConversationId(), saved.getId());

                processed++;
                logger.info("Message processed: {} -> {}", buffered.getServerId(), saved.getId());

            } catch (Exception e) {
                logger.error("Failed to process message: {}", buffered.getServerId(), e);
                handleFailedMessage(buffered, e);
            }
        }
    }

    private void handleFailedMessage(BufferedMessage msg, Exception e) {
        msg.setRetryCount(msg.getRetryCount() + 1);

        if (msg.getRetryCount() < 3) {
            // Retry
            queueService.queueMessage(msg);
            logger.info("Message requeued for retry (attempt {}): {}", msg.getRetryCount(), msg.getServerId());
        } else {
            // Dead letter queue (log or store separately)
            logger.error("Message failed after 3 retries: {}", msg.getServerId());
            notifyMessageFailed(msg.getDeviceId(), msg.getServerId());
        }
    }

    private void notifyMessageDelivered(String deviceId, UUID serverId, UUID messageId) {
        Map<String, Object> payload = Map.of(
            "type", "MESSAGE_DELIVERED",
            "serverId", serverId.toString(),
            "messageId", messageId.toString(),
            "deliveredAt", Instant.now().toString()
        );

        messagingTemplate.convertAndSendToUser(
            deviceId,
            "/queue/notifications",
            payload
        );

        logger.debug("Sent MESSAGE_DELIVERED notification to device {}", deviceId);
    }

    private void notifyNewMessage(UUID conversationId, UUID messageId) {
        Map<String, Object> payload = Map.of(
            "type", "NEW_MESSAGE",
            "conversationId", conversationId.toString(),
            "messageId", messageId.toString()
        );

        messagingTemplate.convertAndSend(
            "/topic/conversation/" + conversationId,
            payload
        );

        logger.debug("Sent NEW_MESSAGE notification for conversation {}", conversationId);
    }

    private void notifyMessageFailed(String deviceId, UUID serverId) {
        Map<String, Object> payload = Map.of(
            "type", "MESSAGE_FAILED",
            "serverId", serverId.toString(),
            "failedAt", Instant.now().toString()
        );

        messagingTemplate.convertAndSendToUser(
            deviceId,
            "/queue/notifications",
            payload
        );

        logger.error("Sent MESSAGE_FAILED notification to device {}", deviceId);
    }
}
