package pt.sousavf.securemessaging.repository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Repository;
import pt.sousavf.securemessaging.entity.Conversation;

import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

/**
 * Redis repository for conversation caching
 * Provides fast access to conversations with automatic expiry
 */
@Repository
public class ConversationRedisRepository {

    private static final String CONVERSATION_KEY_PREFIX = "conversation:";
    private static final String DEVICE_CONVERSATIONS_KEY_PREFIX = "device_conversations:";
    private static final long CONVERSATION_CACHE_TTL_DAYS = 7;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    /**
     * Store a conversation in Redis cache
     *
     * @param conversation The conversation to cache
     */
    public void storeConversation(Conversation conversation) {
        try {
            String key = CONVERSATION_KEY_PREFIX + conversation.getId().toString();
            redisTemplate.opsForValue().set(key, conversation, CONVERSATION_CACHE_TTL_DAYS, TimeUnit.DAYS);
        } catch (Exception e) {
            System.err.println("Failed to store conversation in Redis: " + e.getMessage());
        }
    }

    /**
     * Retrieve a conversation from cache
     *
     * @param conversationId The conversation ID
     * @return The cached conversation, or null if not found
     */
    public Conversation getConversation(UUID conversationId) {
        try {
            String key = CONVERSATION_KEY_PREFIX + conversationId.toString();
            Object cached = redisTemplate.opsForValue().get(key);
            if (cached instanceof Conversation) {
                return (Conversation) cached;
            }
            return null;
        } catch (Exception e) {
            System.err.println("Failed to retrieve conversation from Redis: " + e.getMessage());
            return null;
        }
    }

    /**
     * Check if conversation exists in cache
     *
     * @param conversationId The conversation ID
     * @return true if conversation is cached, false otherwise
     */
    public boolean hasConversation(UUID conversationId) {
        try {
            String key = CONVERSATION_KEY_PREFIX + conversationId.toString();
            return Boolean.TRUE.equals(redisTemplate.hasKey(key));
        } catch (Exception e) {
            System.err.println("Failed to check conversation in Redis: " + e.getMessage());
            return false;
        }
    }

    /**
     * Store all conversations for a device
     *
     * @param deviceId The device ID
     * @param conversations List of conversations
     */
    public void storeDeviceConversations(String deviceId, List<Conversation> conversations) {
        try {
            String key = DEVICE_CONVERSATIONS_KEY_PREFIX + deviceId;
            redisTemplate.delete(key);

            if (conversations != null && !conversations.isEmpty()) {
                for (Conversation conversation : conversations) {
                    redisTemplate.opsForSet().add(key, conversation);
                    // Also cache individual conversation
                    storeConversation(conversation);
                }
                redisTemplate.expire(key, CONVERSATION_CACHE_TTL_DAYS, TimeUnit.DAYS);
            }
        } catch (Exception e) {
            System.err.println("Failed to store device conversations in Redis: " + e.getMessage());
        }
    }

    /**
     * Retrieve all conversations for a device
     *
     * @param deviceId The device ID
     * @return List of cached conversations, or empty list if not found
     */
    public List<Conversation> getDeviceConversations(String deviceId) {
        try {
            String key = DEVICE_CONVERSATIONS_KEY_PREFIX + deviceId;
            Set<Object> cached = redisTemplate.opsForSet().members(key);

            if (cached != null && !cached.isEmpty()) {
                return cached.stream()
                        .filter(obj -> obj instanceof Conversation)
                        .map(obj -> (Conversation) obj)
                        .collect(Collectors.toList());
            }
            return new ArrayList<>();
        } catch (Exception e) {
            System.err.println("Failed to retrieve device conversations from Redis: " + e.getMessage());
            return new ArrayList<>();
        }
    }

    /**
     * Check if device conversations are cached
     *
     * @param deviceId The device ID
     * @return true if device conversations are cached, false otherwise
     */
    public boolean hasDeviceConversations(String deviceId) {
        try {
            String key = DEVICE_CONVERSATIONS_KEY_PREFIX + deviceId;
            return Boolean.TRUE.equals(redisTemplate.hasKey(key));
        } catch (Exception e) {
            System.err.println("Failed to check device conversations in Redis: " + e.getMessage());
            return false;
        }
    }

    /**
     * Invalidate conversation from cache
     *
     * @param conversationId The conversation ID
     */
    public void invalidateConversation(UUID conversationId) {
        try {
            String key = CONVERSATION_KEY_PREFIX + conversationId.toString();
            redisTemplate.delete(key);
        } catch (Exception e) {
            System.err.println("Failed to invalidate conversation in Redis: " + e.getMessage());
        }
    }

    /**
     * Invalidate all conversations for a device
     *
     * @param deviceId The device ID
     */
    public void invalidateDeviceConversations(String deviceId) {
        try {
            String key = DEVICE_CONVERSATIONS_KEY_PREFIX + deviceId;
            Set<Object> conversations = redisTemplate.opsForSet().members(key);

            if (conversations != null) {
                for (Object conv : conversations) {
                    if (conv instanceof Conversation) {
                        invalidateConversation(((Conversation) conv).getId());
                    }
                }
            }

            redisTemplate.delete(key);
        } catch (Exception e) {
            System.err.println("Failed to invalidate device conversations in Redis: " + e.getMessage());
        }
    }

    /**
     * Add a conversation to device's conversation list
     *
     * @param deviceId The device ID
     * @param conversation The conversation to add
     */
    public void addConversationToDevice(String deviceId, Conversation conversation) {
        try {
            String key = DEVICE_CONVERSATIONS_KEY_PREFIX + deviceId;
            redisTemplate.opsForSet().add(key, conversation);
            // Also cache individual conversation
            storeConversation(conversation);
            redisTemplate.expire(key, CONVERSATION_CACHE_TTL_DAYS, TimeUnit.DAYS);
        } catch (Exception e) {
            System.err.println("Failed to add conversation to device in Redis: " + e.getMessage());
        }
    }

    /**
     * Remove a conversation from device's conversation list
     *
     * @param deviceId The device ID
     * @param conversationId The conversation ID to remove
     */
    public void removeConversationFromDevice(String deviceId, UUID conversationId) {
        try {
            String key = DEVICE_CONVERSATIONS_KEY_PREFIX + deviceId;
            Set<Object> conversations = redisTemplate.opsForSet().members(key);

            if (conversations != null) {
                Object toRemove = conversations.stream()
                        .filter(conv -> conv instanceof Conversation &&
                                ((Conversation) conv).getId().equals(conversationId))
                        .findFirst()
                        .orElse(null);

                if (toRemove != null) {
                    redisTemplate.opsForSet().remove(key, toRemove);
                }
            }

            invalidateConversation(conversationId);
        } catch (Exception e) {
            System.err.println("Failed to remove conversation from device in Redis: " + e.getMessage());
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
