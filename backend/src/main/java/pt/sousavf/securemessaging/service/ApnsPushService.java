package pt.sousavf.securemessaging.service;

import com.eatthepath.pushy.apns.ApnsClient;
import com.eatthepath.pushy.apns.ApnsClientBuilder;
import com.eatthepath.pushy.apns.PushNotificationResponse;
import com.eatthepath.pushy.apns.util.SimpleApnsPushNotification;
import com.eatthepath.pushy.apns.auth.ApnsSigningKey;
import com.google.common.hash.Hashing;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import pt.sousavf.securemessaging.entity.DeviceToken;
import pt.sousavf.securemessaging.repository.DeviceTokenRepository;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import jakarta.annotation.PostConstruct;

@Service
@ConditionalOnProperty(name = "apns.enabled", havingValue = "true", matchIfMissing = false)
public class ApnsPushService {

    private static final Logger logger = LoggerFactory.getLogger(ApnsPushService.class);

    private ApnsClient apnsClient;

    @Value("${apns.key.path}")
    private String keyPath;

    @Value("${apns.key.id}")
    private String keyId;

    @Value("${apns.team.id}")
    private String teamId;

    @Value("${apns.topic}")
    private String topic;

    @Value("${apns.enabled}")
    private boolean apnsEnabled;

    private final DeviceTokenRepository deviceTokenRepository;

    public ApnsPushService(DeviceTokenRepository deviceTokenRepository) {
        this.deviceTokenRepository = deviceTokenRepository;
    }

    /**
     * Initialize APNs client after properties are loaded
     */
    @PostConstruct
    public void initializeClient() {
        if (!apnsEnabled) {
            logger.info("APNs is disabled");
            return;
        }

        try {
            logger.info("Initializing APNs client with team ID: {} and key ID: {}", teamId, keyId);

            // Load signing key from file
            ApnsSigningKey signingKey = ApnsSigningKey.loadFromPkcs8File(
                    new File(keyPath),
                    teamId,
                    keyId
            );

            apnsClient = new ApnsClientBuilder()
                    .setApnsServer("api.sandbox.push.apple.com")
                    //.setApnsServer("api.push.apple.com")
                    .setSigningKey(signingKey)
                    .build();

            logger.info("APNs client initialized successfully");
        } catch (IOException | java.security.NoSuchAlgorithmException | java.security.InvalidKeyException e) {
            logger.error("Failed to initialize APNs client", e);
            throw new RuntimeException("Failed to initialize APNs client", e);
        }
    }

    /**
     * Send a silent push notification to a specific device token
     * Silent notification wakes the app without showing a notification
     */
    public void sendSilentPush(String deviceToken, UUID conversationId) {
        if (!apnsEnabled || apnsClient == null) {
            logger.warn("APNs is not enabled or client not initialized, skipping push");
            return;
        }

        try {
            // Hash conversation ID for privacy
            String hashedConvId = hashConversationId(conversationId);
            logger.debug("Sending silent push to token: {}... for conversation hash: {}",
                    deviceToken.substring(0, Math.min(8, deviceToken.length())), hashedConvId);

            // Build silent notification payload using JSON
            String payload = String.format(
                    "{\"aps\":{\"content-available\":1},\"c\":\"%s\"}",
                    hashedConvId
            );

            SimpleApnsPushNotification notification = new SimpleApnsPushNotification(
                    deviceToken,
                    topic,
                    payload
            );

            // Send asynchronously
            sendNotificationAsync(notification, deviceToken);

        } catch (Exception e) {
            logger.error("Error building silent push notification for conversation {}", conversationId, e);
        }
    }

    /**
     * Send alert push notification (with sound/badge)
     */
    public void sendAlertPush(String deviceToken, UUID conversationId, String alertTitle, String alertBody) {
        if (!apnsEnabled || apnsClient == null) {
            logger.warn("APNs is not enabled or client not initialized, skipping push");
            return;
        }

        try {
            String hashedConvId = hashConversationId(conversationId);
            logger.info("Sending alert push to token: {}... for conversation: {} (hash: {})",
                    deviceToken.substring(0, Math.min(8, deviceToken.length())), conversationId, hashedConvId);

            // Build alert notification payload using JSON
            String payload = String.format(
                    "{\"aps\":{\"alert\":{\"title\":\"%s\",\"body\":\"%s\"},\"sound\":\"default\",\"mutable-content\":1},\"c\":\"%s\"}",
                    escapeJson(alertTitle),
                    escapeJson(alertBody),
                    hashedConvId
            );

            SimpleApnsPushNotification notification = new SimpleApnsPushNotification(
                    deviceToken,
                    topic,
                    payload
            );

            sendNotificationAsync(notification, deviceToken);

        } catch (Exception e) {
            logger.error("Error building alert push notification for conversation {}", conversationId, e);
        }
    }

    /**
     * Send silent push to all participants in a conversation except the sender
     */
    @Async
    public void sendPushToConversationParticipants(
            UUID conversationId,
            List<String> participantDeviceIds,
            String excludeDeviceId) {

        // Filter out the sending device
        List<String> recipientDevices = participantDeviceIds.stream()
                .filter(deviceId -> !deviceId.equals(excludeDeviceId))
                .toList();

        if (recipientDevices.isEmpty()) {
            logger.debug("No recipient devices to send push for conversation {}", conversationId);
            return;
        }

        logger.info("Sending push to {} recipients for conversation {}",
                recipientDevices.size(), conversationId);

        // Get device tokens for recipients
        List<DeviceToken> allTokens = deviceTokenRepository.findByDeviceIdIn(recipientDevices);
        logger.info("Found {} total tokens for {} recipient devices", allTokens.size(), recipientDevices.size());

        List<DeviceToken> tokens = allTokens.stream()
                .filter(DeviceToken::isActive)
                .toList();

        logger.info("Found {} active tokens after filtering", tokens.size());

        for (DeviceToken token : tokens) {
            logger.info("Calling sendAlertPush for token: {}... conversation: {}",
                    token.getApnsToken().substring(0, Math.min(8, token.getApnsToken().length())), conversationId);
            sendAlertPush(token.getApnsToken(), conversationId, "New Message", "You have a new message");
        }
    }

    /**
     * Send deletion notification to all participants in a conversation except the initiator
     */
    @Async
    public void sendConversationDeletedPush(UUID conversationId, List<String> participantDeviceIds, String excludeDeviceId) {
        // Filter out the initiator who deleted it
        List<String> recipientDevices = participantDeviceIds.stream()
                .filter(deviceId -> !deviceId.equals(excludeDeviceId))
                .toList();

        if (recipientDevices.isEmpty()) {
            logger.debug("No recipient devices to notify for conversation deletion {}", conversationId);
            return;
        }

        logger.info("Sending deletion notification to {} recipients for conversation {}",
                recipientDevices.size(), conversationId);

        // Get device tokens for recipients
        List<DeviceToken> tokens = deviceTokenRepository.findByDeviceIdIn(recipientDevices).stream()
                .filter(DeviceToken::isActive)
                .toList();

        logger.info("Found {} active tokens for deletion notification", tokens.size());

        for (DeviceToken token : tokens) {
            sendConversationDeletedAlert(token.getApnsToken(), conversationId);
        }
    }

    /**
     * Send expiration notification to all participants in a conversation
     */
    @Async
    public void sendConversationExpiredPush(UUID conversationId, List<String> participantDeviceIds) {
        if (participantDeviceIds.isEmpty()) {
            logger.debug("No recipient devices to notify for conversation expiration {}", conversationId);
            return;
        }

        logger.info("Sending expiration notification to {} recipients for conversation {}",
                participantDeviceIds.size(), conversationId);

        // Get device tokens for all participants
        List<DeviceToken> tokens = deviceTokenRepository.findByDeviceIdIn(participantDeviceIds).stream()
                .filter(DeviceToken::isActive)
                .toList();

        logger.info("Found {} active tokens for expiration notification", tokens.size());

        for (DeviceToken token : tokens) {
            sendConversationExpiredAlert(token.getApnsToken(), conversationId);
        }
    }

    /**
     * Send alert for conversation deletion
     */
    private void sendConversationDeletedAlert(String deviceToken, UUID conversationId) {
        if (!apnsEnabled || apnsClient == null) {
            logger.warn("APNs is not enabled or client not initialized, skipping push");
            return;
        }

        try {
            String hashedConvId = hashConversationId(conversationId);
            logger.info("Sending deletion alert to token: {}... for conversation: {} (hash: {})",
                    deviceToken.substring(0, Math.min(8, deviceToken.length())), conversationId, hashedConvId);

            // Build deletion alert payload
            String payload = String.format(
                    "{\"aps\":{\"alert\":{\"title\":\"Conversation Deleted\",\"body\":\"This conversation has been deleted\"},\"sound\":\"default\",\"mutable-content\":1},\"c\":\"%s\",\"type\":\"deleted\"}",
                    hashedConvId
            );

            SimpleApnsPushNotification notification = new SimpleApnsPushNotification(
                    deviceToken,
                    topic,
                    payload
            );

            sendNotificationAsync(notification, deviceToken);

        } catch (Exception e) {
            logger.error("Error building deletion alert push notification for conversation {}", conversationId, e);
        }
    }

    /**
     * Send alert for conversation expiration
     */
    private void sendConversationExpiredAlert(String deviceToken, UUID conversationId) {
        if (!apnsEnabled || apnsClient == null) {
            logger.warn("APNs is not enabled or client not initialized, skipping push");
            return;
        }

        try {
            String hashedConvId = hashConversationId(conversationId);
            logger.info("Sending expiration alert to token: {}... for conversation: {} (hash: {})",
                    deviceToken.substring(0, Math.min(8, deviceToken.length())), conversationId, hashedConvId);

            // Build expiration alert payload
            String payload = String.format(
                    "{\"aps\":{\"alert\":{\"title\":\"Conversation Expired\",\"body\":\"This conversation has expired\"},\"sound\":\"default\",\"mutable-content\":1},\"c\":\"%s\",\"type\":\"expired\"}",
                    hashedConvId
            );

            SimpleApnsPushNotification notification = new SimpleApnsPushNotification(
                    deviceToken,
                    topic,
                    payload
            );

            sendNotificationAsync(notification, deviceToken);

        } catch (Exception e) {
            logger.error("Error building expiration alert push notification for conversation {}", conversationId, e);
        }
    }

    /**
     * Send notification asynchronously and handle response
     */
    private void sendNotificationAsync(SimpleApnsPushNotification notification, String deviceToken) {
        if (apnsClient == null) {
            return;
        }

        CompletableFuture<PushNotificationResponse<SimpleApnsPushNotification>> future =
                apnsClient.sendNotification(notification);

        future.whenComplete((response, error) -> {
            if (error != null) {
                logger.error("Push notification failed for device token: {}... error: {}",
                        deviceToken.substring(0, Math.min(8, deviceToken.length())), error.getMessage());
            } else if (response.isAccepted()) {
                logger.debug("Push notification accepted for device token: {}...",
                        deviceToken.substring(0, Math.min(8, deviceToken.length())));
            } else {
                String rejection = response.getRejectionReason().orElse("Unknown");
                logger.warn("Push notification rejected for device token: {}... reason: {}",
                        deviceToken.substring(0, Math.min(8, deviceToken.length())), rejection);

                // Handle invalid/expired tokens
                if ("BadDeviceToken".equals(rejection) || "Unregistered".equals(rejection)) {
                    logger.info("Removing invalid device token");
                    deviceTokenRepository.findByApnsToken(deviceToken).ifPresent(token -> {
                        token.setActive(false);
                        deviceTokenRepository.save(token);
                    });
                }
            }
        });
    }

    /**
     * Hash conversation ID for privacy (matching iOS implementation)
     * Returns first 32 characters of SHA256 hash
     * IMPORTANT: Convert UUID to lowercase before hashing to match iOS/Java UUID.toString() format
     */
    private String hashConversationId(UUID conversationId) {
        // Convert to lowercase to match Java's UUID.toString() format (lowercase hex)
        String lowercaseUUID = conversationId.toString().toLowerCase();
        return Hashing.sha256()
                .hashString(lowercaseUUID, StandardCharsets.UTF_8)
                .toString()
                .substring(0, 32);
    }

    /**
     * Escape JSON special characters in string
     */
    private String escapeJson(String input) {
        if (input == null) {
            return "";
        }
        return input.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }

    /**
     * Clean up resources (called on shutdown)
     */
    public void shutdown() {
        if (apnsClient != null) {
            try {
                apnsClient.close();
                logger.info("APNs client closed");
            } catch (Exception e) {
                logger.error("Error closing APNs client", e);
                if (e instanceof InterruptedException) {
                    Thread.currentThread().interrupt();
                }
            }
        }
    }
}
