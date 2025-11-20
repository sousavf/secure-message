package pt.sousavf.securemessaging.repository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Repository;
import pt.sousavf.securemessaging.entity.DeviceToken;

import java.util.concurrent.TimeUnit;

/**
 * Redis repository for device token caching and session storage
 * Provides fast access to active device tokens with automatic expiry
 */
@Repository
public class DeviceTokenRedisRepository {

    private static final String DEVICE_TOKEN_KEY_PREFIX = "device_token:";
    private static final String DEVICE_ID_TOKEN_KEY_PREFIX = "device_id_tokens:";
    private static final long DEVICE_TOKEN_TTL_DAYS = 30;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    /**
     * Store device token in Redis with 30-day TTL
     *
     * @param apnsToken The APNs token
     * @param deviceToken The device token object
     */
    public void storeToken(String apnsToken, DeviceToken deviceToken) {
        try {
            String key = DEVICE_TOKEN_KEY_PREFIX + apnsToken;
            redisTemplate.opsForValue().set(key, deviceToken, DEVICE_TOKEN_TTL_DAYS, TimeUnit.DAYS);

            // Also store reverse mapping for quick device ID lookup
            String deviceIdKey = DEVICE_ID_TOKEN_KEY_PREFIX + deviceToken.getDeviceId();
            redisTemplate.opsForSet().add(deviceIdKey, apnsToken);
            redisTemplate.expire(deviceIdKey, DEVICE_TOKEN_TTL_DAYS, TimeUnit.DAYS);
        } catch (Exception e) {
            // Log error but don't fail - Redis is optional, database is fallback
            System.err.println("Failed to store device token in Redis: " + e.getMessage());
        }
    }

    /**
     * Retrieve device token from Redis cache
     *
     * @param apnsToken The APNs token
     * @return The cached device token, or null if not found
     */
    public DeviceToken getToken(String apnsToken) {
        try {
            String key = DEVICE_TOKEN_KEY_PREFIX + apnsToken;
            Object cached = redisTemplate.opsForValue().get(key);
            if (cached instanceof DeviceToken) {
                return (DeviceToken) cached;
            }
            return null;
        } catch (Exception e) {
            // Log error but don't fail - fallback to database
            System.err.println("Failed to retrieve device token from Redis: " + e.getMessage());
            return null;
        }
    }

    /**
     * Check if device token exists in Redis cache
     *
     * @param apnsToken The APNs token
     * @return true if token exists and is active, false otherwise
     */
    public boolean tokenExists(String apnsToken) {
        try {
            String key = DEVICE_TOKEN_KEY_PREFIX + apnsToken;
            return Boolean.TRUE.equals(redisTemplate.hasKey(key));
        } catch (Exception e) {
            // Log error but don't fail
            System.err.println("Failed to check device token existence in Redis: " + e.getMessage());
            return false;
        }
    }

    /**
     * Invalidate device token in Redis cache
     *
     * @param apnsToken The APNs token
     */
    public void invalidateToken(String apnsToken) {
        try {
            String key = DEVICE_TOKEN_KEY_PREFIX + apnsToken;
            redisTemplate.delete(key);
        } catch (Exception e) {
            // Log error but don't fail
            System.err.println("Failed to invalidate device token in Redis: " + e.getMessage());
        }
    }

    /**
     * Invalidate all tokens for a device
     *
     * @param deviceId The device ID
     */
    public void invalidateAllDeviceTokens(String deviceId) {
        try {
            String deviceIdKey = DEVICE_ID_TOKEN_KEY_PREFIX + deviceId;
            Object tokens = redisTemplate.opsForSet().members(deviceIdKey);
            if (tokens != null) {
                for (Object token : (java.util.Set<?>) tokens) {
                    invalidateToken(token.toString());
                }
            }
            redisTemplate.delete(deviceIdKey);
        } catch (Exception e) {
            // Log error but don't fail
            System.err.println("Failed to invalidate device tokens in Redis: " + e.getMessage());
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
