package pt.sousavf.securemessaging.repository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Repository;
import pt.sousavf.securemessaging.entity.Message;

import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

/**
 * Redis repository for message caching
 * Provides fast access to conversation messages with automatic expiry
 */
@Repository
public class MessageRedisRepository {

    private static final String CONVERSATION_MESSAGES_KEY_PREFIX = "conversation_messages:";
    private static final String MESSAGE_KEY_PREFIX = "message:";
    private static final long MESSAGE_CACHE_TTL_HOURS = 24;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    /**
     * Store all messages for a conversation in Redis
     * Useful for caching full conversation message lists
     *
     * @param conversationId The conversation ID
     * @param messages List of messages
     */
    public void storeConversationMessages(UUID conversationId, List<Message> messages) {
        try {
            String key = CONVERSATION_MESSAGES_KEY_PREFIX + conversationId.toString();
            redisTemplate.delete(key);

            if (messages != null && !messages.isEmpty()) {
                for (Message message : messages) {
                    redisTemplate.opsForList().rightPush(key, message);
                }
                redisTemplate.expire(key, MESSAGE_CACHE_TTL_HOURS, TimeUnit.HOURS);
            }
        } catch (Exception e) {
            System.err.println("Failed to store conversation messages in Redis: " + e.getMessage());
        }
    }

    /**
     * Add a single message to the conversation message list
     *
     * @param conversationId The conversation ID
     * @param message The message to add
     */
    public void addMessage(UUID conversationId, Message message) {
        try {
            String key = CONVERSATION_MESSAGES_KEY_PREFIX + conversationId.toString();
            redisTemplate.opsForList().rightPush(key, message);
            redisTemplate.expire(key, MESSAGE_CACHE_TTL_HOURS, TimeUnit.HOURS);
        } catch (Exception e) {
            System.err.println("Failed to add message to Redis: " + e.getMessage());
        }
    }

    /**
     * Retrieve all cached messages for a conversation
     *
     * @param conversationId The conversation ID
     * @return List of cached messages, or empty list if not found
     */
    public List<Message> getConversationMessages(UUID conversationId) {
        try {
            String key = CONVERSATION_MESSAGES_KEY_PREFIX + conversationId.toString();
            List<Object> cached = redisTemplate.opsForList().range(key, 0, -1);

            if (cached != null && !cached.isEmpty()) {
                return cached.stream()
                        .filter(obj -> obj instanceof Message)
                        .map(obj -> (Message) obj)
                        .collect(Collectors.toList());
            }
            return new ArrayList<>();
        } catch (Exception e) {
            System.err.println("Failed to retrieve conversation messages from Redis: " + e.getMessage());
            return new ArrayList<>();
        }
    }

    /**
     * Check if conversation messages are cached
     *
     * @param conversationId The conversation ID
     * @return true if messages are cached, false otherwise
     */
    public boolean hasConversationMessages(UUID conversationId) {
        try {
            String key = CONVERSATION_MESSAGES_KEY_PREFIX + conversationId.toString();
            return Boolean.TRUE.equals(redisTemplate.hasKey(key));
        } catch (Exception e) {
            System.err.println("Failed to check conversation messages in Redis: " + e.getMessage());
            return false;
        }
    }

    /**
     * Invalidate conversation message cache
     *
     * @param conversationId The conversation ID
     */
    public void invalidateConversationMessages(UUID conversationId) {
        try {
            String key = CONVERSATION_MESSAGES_KEY_PREFIX + conversationId.toString();
            redisTemplate.delete(key);
        } catch (Exception e) {
            System.err.println("Failed to invalidate conversation messages in Redis: " + e.getMessage());
        }
    }

    /**
     * Store individual message for quick lookup
     *
     * @param message The message to store
     */
    public void storeMessage(Message message) {
        try {
            String key = MESSAGE_KEY_PREFIX + message.getId().toString();
            redisTemplate.opsForValue().set(key, message, MESSAGE_CACHE_TTL_HOURS, TimeUnit.HOURS);
        } catch (Exception e) {
            System.err.println("Failed to store message in Redis: " + e.getMessage());
        }
    }

    /**
     * Retrieve a specific message from cache
     *
     * @param messageId The message ID
     * @return The cached message, or null if not found
     */
    public Message getMessage(UUID messageId) {
        try {
            String key = MESSAGE_KEY_PREFIX + messageId.toString();
            Object cached = redisTemplate.opsForValue().get(key);
            if (cached instanceof Message) {
                return (Message) cached;
            }
            return null;
        } catch (Exception e) {
            System.err.println("Failed to retrieve message from Redis: " + e.getMessage());
            return null;
        }
    }

    /**
     * Invalidate a specific message from cache
     *
     * @param messageId The message ID
     */
    public void invalidateMessage(UUID messageId) {
        try {
            String key = MESSAGE_KEY_PREFIX + messageId.toString();
            redisTemplate.delete(key);
        } catch (Exception e) {
            System.err.println("Failed to invalidate message in Redis: " + e.getMessage());
        }
    }

    /**
     * Check if Redis is available for operations
     *
     * @return true if Redis is available, false otherwise
     */
    public boolean isAvailable() {
        try {
            redisTemplate.getConnectionFactory().getConnection().ping();
            return true;
        } catch (Exception e) {
            System.err.println("Redis is not available: " + e.getMessage());
            return false;
        }
    }
}
