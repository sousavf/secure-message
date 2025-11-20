package pt.sousavf.securemessaging.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import pt.sousavf.securemessaging.entity.DeviceToken;
import pt.sousavf.securemessaging.repository.DeviceTokenRepository;

import java.util.List;
import java.util.Optional;

@Service
public class DeviceTokenService {

    private static final Logger logger = LoggerFactory.getLogger(DeviceTokenService.class);

    private final DeviceTokenRepository deviceTokenRepository;

    public DeviceTokenService(DeviceTokenRepository deviceTokenRepository) {
        this.deviceTokenRepository = deviceTokenRepository;
    }

    /**
     * Register or update an APNs token for a device
     */
    public DeviceToken registerToken(String deviceId, String apnsToken) {
        logger.info("Registering APNs token for device: {}", deviceId);

        // Check if device already has this token
        Optional<DeviceToken> existingToken = deviceTokenRepository.findByApnsToken(apnsToken);
        if (existingToken.isPresent()) {
            // Token already registered for this device
            if (existingToken.get().getDeviceId().equals(deviceId)) {
                logger.debug("Token already registered for device {}, updating timestamp", deviceId);
                DeviceToken token = existingToken.get();
                token.setActive(true);
                return deviceTokenRepository.save(token);
            } else {
                // Token was previously registered to a different device (device switch)
                logger.info("Token moving from device {} to device {}", existingToken.get().getDeviceId(), deviceId);
                existingToken.get().setActive(false);
                deviceTokenRepository.save(existingToken.get());
            }
        }

        // Deactivate any previous tokens for this device
        List<DeviceToken> previousTokens = deviceTokenRepository.findAllByDeviceId(deviceId);
        for (DeviceToken token : previousTokens) {
            token.setActive(false);
            deviceTokenRepository.save(token);
        }

        // Create and save new token
        DeviceToken newToken = new DeviceToken(deviceId, apnsToken);
        DeviceToken savedToken = deviceTokenRepository.save(newToken);
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
        logger.info("All tokens removed for device: {}", deviceId);
    }
}
