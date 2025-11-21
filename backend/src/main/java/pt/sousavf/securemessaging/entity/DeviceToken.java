package pt.sousavf.securemessaging.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "device_tokens", indexes = {
    // For finding all tokens for a device (push notification delivery)
    @Index(name = "idx_device_id_active", columnList = "device_id, active"),
    // For finding token by APNs token (validation)
    @Index(name = "idx_apns_token", columnList = "apns_token"),
    // For cleanup of old inactive tokens
    @Index(name = "idx_updated_at", columnList = "updated_at"),
    // Simple lookups
    @Index(name = "idx_device_id", columnList = "device_id")
})
public class DeviceToken {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String deviceId;

    @Column(nullable = false, unique = true)
    private String apnsToken;

    @Column(nullable = false)
    private LocalDateTime registeredAt = LocalDateTime.now();

    @Column(nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now();

    @Column(nullable = false)
    private boolean active = true;

    // Constructors
    public DeviceToken() {
    }

    public DeviceToken(String deviceId, String apnsToken) {
        this.deviceId = deviceId;
        this.apnsToken = apnsToken;
        this.registeredAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        this.active = true;
    }

    // Getters and Setters
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

    public String getApnsToken() {
        return apnsToken;
    }

    public void setApnsToken(String apnsToken) {
        this.apnsToken = apnsToken;
    }

    public LocalDateTime getRegisteredAt() {
        return registeredAt;
    }

    public void setRegisteredAt(LocalDateTime registeredAt) {
        this.registeredAt = registeredAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
