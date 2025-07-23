package pt.sousavf.securemessaging.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;
import pt.sousavf.securemessaging.entity.User;
import pt.sousavf.securemessaging.repository.UserRepository;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@Service
@Transactional
public class SubscriptionService {

    private static final Logger logger = LoggerFactory.getLogger(SubscriptionService.class);
    
    private final UserRepository userRepository;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    
    @Value("${app.subscription.app-shared-secret:}")
    private String appSharedSecret;
    
    @Value("${app.subscription.sandbox:true}")
    private boolean useSandbox;
    
    private static final String PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt";
    private static final String SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

    public SubscriptionService(UserRepository userRepository) {
        this.userRepository = userRepository;
        this.restTemplate = new RestTemplate();
        this.objectMapper = new ObjectMapper();
    }

    public User getOrCreateUser(String deviceId) {
        return userRepository.findByDeviceId(deviceId)
                .orElseGet(() -> {
                    User newUser = new User(deviceId);
                    return userRepository.save(newUser);
                });
    }

    @Transactional
    public boolean verifyAndUpdateSubscription(String deviceId, String receiptData) {
        try {
            User user = getOrCreateUser(deviceId);
            
            // Verify receipt with Apple
            ReceiptValidationResult result = verifyReceiptWithApple(receiptData);
            
            if (result.isValid()) {
                updateUserSubscription(user, result, receiptData);
                return true;
            } else {
                logger.warn("Receipt validation failed for device: {}, reason: {}", deviceId, result.getErrorMessage());
                // Set user to free tier if receipt is invalid
                user.setSubscriptionStatus(User.SubscriptionStatus.FREE);
                user.setSubscriptionExpiresAt(null);
                userRepository.save(user);
                return false;
            }
        } catch (Exception e) {
            logger.error("Error verifying subscription for device: {}", deviceId, e);
            return false;
        }
    }

    private ReceiptValidationResult verifyReceiptWithApple(String receiptData) {
        try {
            String url = useSandbox ? SANDBOX_URL : PRODUCTION_URL;
            
            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("receipt-data", receiptData);
            if (!appSharedSecret.isEmpty()) {
                requestBody.put("password", appSharedSecret);
            }

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            
            HttpEntity<Map<String, Object>> requestEntity = new HttpEntity<>(requestBody, headers);
            
            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, requestEntity, String.class);
            
            if (response.getStatusCode() == HttpStatus.OK) {
                JsonNode responseJson = objectMapper.readTree(response.getBody());
                return parseAppleResponse(responseJson);
            } else {
                return ReceiptValidationResult.invalid("HTTP error: " + response.getStatusCode());
            }
        } catch (Exception e) {
            logger.error("Error communicating with Apple's verification service", e);
            return ReceiptValidationResult.invalid("Network error: " + e.getMessage());
        }
    }

    private ReceiptValidationResult parseAppleResponse(JsonNode response) {
        int status = response.path("status").asInt();
        
        if (status == 0) {
            // Valid receipt
            JsonNode receipt = response.path("receipt");
            JsonNode latestReceiptInfo = response.path("latest_receipt_info");
            
            if (latestReceiptInfo.isArray() && latestReceiptInfo.size() > 0) {
                // Get the most recent subscription
                JsonNode latestSub = latestReceiptInfo.get(latestReceiptInfo.size() - 1);
                
                String expiresDateMs = latestSub.path("expires_date_ms").asText();
                String originalTransactionId = latestSub.path("original_transaction_id").asText();
                
                if (!expiresDateMs.isEmpty()) {
                    long expiresTimestamp = Long.parseLong(expiresDateMs);
                    LocalDateTime expiresAt = LocalDateTime.ofInstant(
                        Instant.ofEpochMilli(expiresTimestamp), ZoneOffset.UTC);
                    
                    return ReceiptValidationResult.valid(originalTransactionId, expiresAt);
                }
            }
            return ReceiptValidationResult.invalid("No valid subscription found in receipt");
        } else {
            String errorMessage = getAppleErrorMessage(status);
            logger.warn("Apple receipt validation failed with status: {}, message: {}", status, errorMessage);
            return ReceiptValidationResult.invalid(errorMessage);
        }
    }

    private String getAppleErrorMessage(int status) {
        return switch (status) {
            case 21000 -> "The App Store could not read the JSON object you provided.";
            case 21002 -> "The data in the receipt-data property was malformed or missing.";
            case 21003 -> "The receipt could not be authenticated.";
            case 21004 -> "The shared secret you provided does not match the shared secret on file for your account.";
            case 21005 -> "The receipt server is not currently available.";
            case 21006 -> "This receipt is valid but the subscription has expired.";
            case 21007 -> "This receipt is from the test environment, but it was sent to the production environment for verification.";
            case 21008 -> "This receipt is from the production environment, but it was sent to the test environment for verification.";
            case 21010 -> "This receipt could not be authorized. Treat this the same as if a purchase was never made.";
            default -> "Unknown error (status: " + status + ")";
        };
    }

    private void updateUserSubscription(User user, ReceiptValidationResult result, String receiptData) {
        user.setOriginalTransactionId(result.getOriginalTransactionId());
        user.setLatestReceiptData(receiptData);
        user.setSubscriptionExpiresAt(result.getExpiresAt());
        
        // Determine subscription status based on expiration
        if (result.getExpiresAt().isAfter(LocalDateTime.now())) {
            user.setSubscriptionStatus(User.SubscriptionStatus.PREMIUM_ACTIVE);
        } else {
            user.setSubscriptionStatus(User.SubscriptionStatus.PREMIUM_EXPIRED);
        }
        
        userRepository.save(user);
        logger.info("Updated subscription for device: {}, status: {}, expires: {}", 
                   user.getDeviceId(), user.getSubscriptionStatus(), user.getSubscriptionExpiresAt());
    }

    public boolean canSendLargeMessage(String deviceId) {
        Optional<User> userOpt = userRepository.findByDeviceId(deviceId);
        if (userOpt.isEmpty()) {
            return false;
        }
        return userOpt.get().isPremiumActive();
    }

    public long getMaxMessageSize(String deviceId) {
        Optional<User> userOpt = userRepository.findByDeviceId(deviceId);
        if (userOpt.isEmpty()) {
            return 102_400L; // 100KB for non-registered users
        }
        return userOpt.get().getMaxMessageSizeBytes();
    }

    // Inner class for validation results
    private static class ReceiptValidationResult {
        private final boolean valid;
        private final String errorMessage;
        private final String originalTransactionId;
        private final LocalDateTime expiresAt;

        private ReceiptValidationResult(boolean valid, String errorMessage, String originalTransactionId, LocalDateTime expiresAt) {
            this.valid = valid;
            this.errorMessage = errorMessage;
            this.originalTransactionId = originalTransactionId;
            this.expiresAt = expiresAt;
        }

        public static ReceiptValidationResult valid(String originalTransactionId, LocalDateTime expiresAt) {
            return new ReceiptValidationResult(true, null, originalTransactionId, expiresAt);
        }

        public static ReceiptValidationResult invalid(String errorMessage) {
            return new ReceiptValidationResult(false, errorMessage, null, null);
        }

        public boolean isValid() { return valid; }
        public String getErrorMessage() { return errorMessage; }
        public String getOriginalTransactionId() { return originalTransactionId; }
        public LocalDateTime getExpiresAt() { return expiresAt; }
    }
}