package pt.sousavf.securemessaging.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "users", indexes = {
    @Index(name = "idx_user_device_id", columnList = "deviceId", unique = true),
    @Index(name = "idx_user_subscription_expires", columnList = "subscriptionExpiresAt"),
    @Index(name = "idx_user_subscription_status", columnList = "subscriptionStatus")
})
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @NotBlank(message = "Device ID cannot be blank")
    @Size(max = 255, message = "Device ID too large")
    @Column(name = "device_id", nullable = false, unique = true)
    private String deviceId;

    @Enumerated(EnumType.STRING)
    @Column(name = "subscription_status", nullable = false)
    private SubscriptionStatus subscriptionStatus = SubscriptionStatus.FREE;

    @Column(name = "subscription_expires_at")
    private LocalDateTime subscriptionExpiresAt;

    @Size(max = 500, message = "Receipt data too large")
    @Column(name = "latest_receipt_data", columnDefinition = "TEXT")
    private String latestReceiptData;

    @Column(name = "original_transaction_id")
    private String originalTransactionId;

    @Column(name = "is_business_user", nullable = false)
    private boolean isBusinessUser = false;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public enum SubscriptionStatus {
        FREE,
        PREMIUM_ACTIVE,
        PREMIUM_EXPIRED,
        PREMIUM_CANCELLED
    }

    public User() {}

    public User(String deviceId) {
        this.deviceId = deviceId;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getDeviceId() {
        return deviceId;
    }

    public void setDeviceId(String deviceId) {
        this.deviceId = deviceId;
    }

    public SubscriptionStatus getSubscriptionStatus() {
        return subscriptionStatus;
    }

    public void setSubscriptionStatus(SubscriptionStatus subscriptionStatus) {
        this.subscriptionStatus = subscriptionStatus;
    }

    public LocalDateTime getSubscriptionExpiresAt() {
        return subscriptionExpiresAt;
    }

    public void setSubscriptionExpiresAt(LocalDateTime subscriptionExpiresAt) {
        this.subscriptionExpiresAt = subscriptionExpiresAt;
    }

    public String getLatestReceiptData() {
        return latestReceiptData;
    }

    public void setLatestReceiptData(String latestReceiptData) {
        this.latestReceiptData = latestReceiptData;
    }

    public String getOriginalTransactionId() {
        return originalTransactionId;
    }

    public void setOriginalTransactionId(String originalTransactionId) {
        this.originalTransactionId = originalTransactionId;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public boolean isBusinessUser() {
        return isBusinessUser;
    }

    public void setBusinessUser(boolean businessUser) {
        isBusinessUser = businessUser;
    }

    public boolean isPremiumActive() {
        return subscriptionStatus == SubscriptionStatus.PREMIUM_ACTIVE &&
               subscriptionExpiresAt != null &&
               LocalDateTime.now().isBefore(subscriptionExpiresAt);
    }

    public long getMaxMessageSizeBytes() {
        return isPremiumActive() ? 10_485_760L : 102_400L; // 10MB vs 100KB
    }
}