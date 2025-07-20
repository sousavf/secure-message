package com.example.securemessaging.service;

import com.example.securemessaging.dto.CreateMessageRequest;
import com.example.securemessaging.dto.MessageResponse;
import com.example.securemessaging.dto.StatsResponse;
import com.example.securemessaging.entity.Message;
import com.example.securemessaging.repository.MessageRepository;
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
    
    @Value("${app.message.default-ttl-hours:24}")
    private int defaultTtlHours;

    public MessageService(MessageRepository messageRepository) {
        this.messageRepository = messageRepository;
    }

    public MessageResponse createMessage(CreateMessageRequest request) {
        logger.info("Creating new message");
        
        LocalDateTime expiresAt = LocalDateTime.now().plusHours(defaultTtlHours);
        
        Message message = new Message(
            request.getCiphertext(),
            request.getNonce(),
            request.getTag(),
            expiresAt
        );
        
        Message savedMessage = messageRepository.save(message);
        logger.info("Message created with ID: {}", savedMessage.getId());
        
        return MessageResponse.createResponse(savedMessage.getId());
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