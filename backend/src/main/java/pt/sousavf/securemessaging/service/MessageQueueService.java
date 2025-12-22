package pt.sousavf.securemessaging.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import pt.sousavf.securemessaging.dto.BufferedMessage;

/**
 * Service for managing message queue in Redis
 * Messages are queued here before async processing to PostgreSQL
 */
@Service
public class MessageQueueService {

    private static final Logger logger = LoggerFactory.getLogger(MessageQueueService.class);
    private static final String MESSAGE_QUEUE = "message_queue";

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    /**
     * Add message to Redis queue (fast, < 10ms)
     */
    public void queueMessage(BufferedMessage message) {
        redisTemplate.opsForList().rightPush(MESSAGE_QUEUE, message);
        logger.info("Message queued: {}", message.getServerId());
    }

    /**
     * Pop message from queue for processing
     */
    public BufferedMessage popMessage() {
        Object obj = redisTemplate.opsForList().leftPop(MESSAGE_QUEUE);
        return obj != null ? (BufferedMessage) obj : null;
    }

    /**
     * Get current queue size
     */
    public Long getQueueSize() {
        return redisTemplate.opsForList().size(MESSAGE_QUEUE);
    }
}
