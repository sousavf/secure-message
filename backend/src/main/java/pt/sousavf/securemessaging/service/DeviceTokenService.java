package pt.sousavf.securemessaging.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import pt.sousavf.securemessaging.entity.DeviceToken;
import pt.sousavf.securemessaging.repository.DeviceTokenRepository;
import pt.sousavf.securemessaging.repository.DeviceTokenRedisRepository;

import java.util.List;
import java.util.Optional;

@Service
public class DeviceTokenService {

    private static final Logger logger = LoggerFactory.getLogger(DeviceTokenService.class);

    private final DeviceTokenRepository deviceTokenRepository;
    private final DeviceTokenRedisRepository redisRepository;

    public DeviceTokenService(DeviceTokenRepository deviceTokenRepository,
                            DeviceTokenRedisRepository redisRepository) {
        this.deviceTokenRepository = deviceTokenRepository;
        this.redisRepository = redisRepository;
    }

    /**
     * Register or update an APNs token for a device
     * Uses write-through strategy: writes to both Redis cache and database
     */
    public DeviceToken registerToken(String deviceId, String apnsToken) {
        logger.info("Registering APNs token for device: {}", deviceId);

        // Check if this token already exists
        Optional<DeviceToken> existingToken = deviceTokenRepository.findByApnsToken(apnsToken);
        if (existingToken.isPresent()) {
            // Token already registered
            if (existingToken.get().getDeviceId().equals(deviceId)) {
                // Same device, same token - just update status
                logger.debug("Token already registered for device {}, updating timestamp", deviceId);
                DeviceToken token = existingToken.get();
                token.setActive(true);
                DeviceToken savedToken = deviceTokenRepository.save(token);
                // Update Redis cache
                redisRepository.storeToken(apnsToken, savedToken);
                return savedToken;
            } else {
                // Token moved to different device - UPDATE existing record instead of creating new
                logger.info("Token moving from device {} to device {}",
                    existingToken.get().getDeviceId(), deviceId);

                // Deactivate any OTHER previous tokens for this NEW device
                // (but not the one we're about to update)
                List<DeviceToken> otherPreviousTokens = deviceTokenRepository.findAllByDeviceId(deviceId);
                for (DeviceToken token : otherPreviousTokens) {
                    token.setActive(false);
                    deviceTokenRepository.save(token);
                    // Invalidate old token in Redis
                    redisRepository.invalidateToken(token.getApnsToken());
                }

                // Update the existing token to point to the new device
                DeviceToken token = existingToken.get();
                token.setDeviceId(deviceId);
                token.setActive(true);
                DeviceToken savedToken = deviceTokenRepository.save(token);
                // Update Redis cache
                redisRepository.storeToken(apnsToken, savedToken);
                logger.info("APNs token transferred to device: {}", deviceId);
                return savedToken;
            }
        }

        // Token doesn't exist yet - create new one
        // But first, deactivate any previous tokens for this device
        List<DeviceToken> previousTokens = deviceTokenRepository.findAllByDeviceId(deviceId);
        for (DeviceToken token : previousTokens) {
            token.setActive(false);
            deviceTokenRepository.save(token);
            // Invalidate old token in Redis
            redisRepository.invalidateToken(token.getApnsToken());
        }

        // Create and save new token
        DeviceToken newToken = new DeviceToken(deviceId, apnsToken);
        DeviceToken savedToken = deviceTokenRepository.save(newToken);
        // Store in Redis cache
        redisRepository.storeToken(apnsToken, savedToken);
        logger.info("APNs token registered successfully for device: {}", deviceId);

        return savedToken;
    }

    /**
     * Get active token for a device
     */
    public Optional<DeviceToken> getActiveToken(String deviceId) {
        return deviceTokenRepository.findByDeviceIdAndActiveTrue(deviceId).stream()
                .findFirst();
    }

    /**
     * Get all active tokens for a list of devices
     */
    public List<DeviceToken> getActiveTokens(List<String> deviceIds) {
        return deviceTokenRepository.findByDeviceIdIn(deviceIds).stream()
                .filter(DeviceToken::isActive)
                .toList();
    }

    /**
     * Deactivate a token (when APNs reports it as invalid)
     */
    public void deactivateToken(String apnsToken) {
        logger.info("Deactivating APNs token");
        deviceTokenRepository.findByApnsToken(apnsToken).ifPresent(token -> {
            token.setActive(false);
            deviceTokenRepository.save(token);
            // Invalidate in Redis cache
            redisRepository.invalidateToken(apnsToken);
            logger.info("Token deactivated for device: {}", token.getDeviceId());
        });
    }

    /**
     * Remove all tokens for a device (when user logs out)
     */
    public void removeAllTokens(String deviceId) {
        logger.info("Removing all tokens for device: {}", deviceId);
        List<DeviceToken> tokens = deviceTokenRepository.findAllByDeviceId(deviceId);
        deviceTokenRepository.deleteAll(tokens);
        // Invalidate all device tokens in Redis
        redisRepository.invalidateAllDeviceTokens(deviceId);
        logger.info("All tokens removed for device: {}", deviceId);
    }
}
