package pt.sousavf.securemessaging.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pt.sousavf.securemessaging.entity.User;
import pt.sousavf.securemessaging.service.SubscriptionService;

import java.time.LocalDateTime;
import java.util.Map;

@RestController
@RequestMapping("/api/subscription")
@CrossOrigin(origins = "*")
public class SubscriptionController {

    private static final Logger logger = LoggerFactory.getLogger(SubscriptionController.class);
    
    private final SubscriptionService subscriptionService;

    public SubscriptionController(SubscriptionService subscriptionService) {
        this.subscriptionService = subscriptionService;
    }

    @PostMapping("/verify")
    public ResponseEntity<SubscriptionStatusResponse> verifySubscription(
            @Valid @RequestBody VerifyReceiptRequest request) {
        
        logger.info("Verifying subscription for device: {}", request.getDeviceId());
        
        boolean isValid = subscriptionService.verifyAndUpdateSubscription(
            request.getDeviceId(), request.getReceiptData());
        
        User user = subscriptionService.getOrCreateUser(request.getDeviceId());
        
        SubscriptionStatusResponse response = new SubscriptionStatusResponse(
            isValid,
            user.getSubscriptionStatus().toString(),
            user.getSubscriptionExpiresAt(),
            user.getMaxMessageSizeBytes()
        );
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/status/{deviceId}")
    public ResponseEntity<SubscriptionStatusResponse> getSubscriptionStatus(
            @PathVariable @NotBlank String deviceId) {
        
        User user = subscriptionService.getOrCreateUser(deviceId);
        
        SubscriptionStatusResponse response = new SubscriptionStatusResponse(
            user.isPremiumActive(),
            user.getSubscriptionStatus().toString(),
            user.getSubscriptionExpiresAt(),
            user.getMaxMessageSizeBytes()
        );
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/limits/{deviceId}")
    public ResponseEntity<Map<String, Object>> getSubscriptionLimits(
            @PathVariable @NotBlank String deviceId) {
        
        long maxMessageSize = subscriptionService.getMaxMessageSize(deviceId);
        boolean canSendLargeMessage = subscriptionService.canSendLargeMessage(deviceId);
        
        return ResponseEntity.ok(Map.of(
            "maxMessageSizeBytes", maxMessageSize,
            "maxMessageSizeMB", maxMessageSize / (1024.0 * 1024.0),
            "canSendLargeMessage", canSendLargeMessage,
            "isPremium", canSendLargeMessage
        ));
    }

    // DTOs
    public static class VerifyReceiptRequest {
        @NotBlank(message = "Device ID is required")
        private String deviceId;
        
        @NotBlank(message = "Receipt data is required")
        private String receiptData;

        public String getDeviceId() { return deviceId; }
        public void setDeviceId(String deviceId) { this.deviceId = deviceId; }
        public String getReceiptData() { return receiptData; }
        public void setReceiptData(String receiptData) { this.receiptData = receiptData; }
    }

    public static class SubscriptionStatusResponse {
        private boolean isActive;
        private String status;
        private LocalDateTime expiresAt;
        private long maxMessageSizeBytes;

        public SubscriptionStatusResponse(boolean isActive, String status, LocalDateTime expiresAt, long maxMessageSizeBytes) {
            this.isActive = isActive;
            this.status = status;
            this.expiresAt = expiresAt;
            this.maxMessageSizeBytes = maxMessageSizeBytes;
        }

        public boolean isActive() { return isActive; }
        public String getStatus() { return status; }
        public LocalDateTime getExpiresAt() { return expiresAt; }
        public long getMaxMessageSizeBytes() { return maxMessageSizeBytes; }
    }
}