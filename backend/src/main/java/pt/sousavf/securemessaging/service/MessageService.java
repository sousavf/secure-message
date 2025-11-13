package pt.sousavf.securemessaging.service;

import pt.sousavf.securemessaging.dto.CreateMessageRequest;
import pt.sousavf.securemessaging.dto.MessageResponse;
import pt.sousavf.securemessaging.dto.StatsResponse;
import pt.sousavf.securemessaging.entity.Message;
import pt.sousavf.securemessaging.repository.MessageRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@Transactional
public class MessageService {

    private static final Logger logger = LoggerFactory.getLogger(MessageService.class);

    private final MessageRepository messageRepository;
    private final SubscriptionService subscriptionService;
    
    @Value("${app.message.default-ttl-hours:24}")
    private int defaultTtlHours;

    public MessageService(MessageRepository messageRepository, SubscriptionService subscriptionService) {
        this.messageRepository = messageRepository;
        this.subscriptionService = subscriptionService;
    }

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

        // Use custom TTL if provided, otherwise use default
        LocalDateTime expiresAt;
        if (request.getTtlMinutes() != null) {
            expiresAt = LocalDateTime.now().plusMinutes(request.getTtlMinutes());
            logger.info("Using custom TTL: {} minutes", request.getTtlMinutes());
        } else {
            expiresAt = LocalDateTime.now().plusHours(defaultTtlHours);
            logger.info("Using default TTL: {} hours", defaultTtlHours);
        }

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
        logger.info("Message created with ID: {}, size: {} bytes, expires at: {}",
                   savedMessage.getId(), estimateMessageSize(request), expiresAt);

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
        
        if (expiredDeleted > 0 || consumedDeleted > 0) {
            logger.info("Cleanup completed: {} expired messages deleted, {} consumed messages deleted", 
                       expiredDeleted, consumedDeleted);
        }
    }
}