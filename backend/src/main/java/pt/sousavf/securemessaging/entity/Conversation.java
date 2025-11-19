package pt.sousavf.securemessaging.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "conversations", indexes = {
    @Index(name = "idx_conversation_initiator", columnList = "initiator_user_id"),
    @Index(name = "idx_conversation_status", columnList = "status"),
    @Index(name = "idx_conversation_expires_at", columnList = "expires_at")
})
public class Conversation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @NotNull
    @Column(name = "initiator_user_id", nullable = false)
    private UUID initiatorUserId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private ConversationStatus status = ConversationStatus.ACTIVE;

    @NotNull
    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public enum ConversationStatus {
        ACTIVE,
        EXPIRED,
        DELETED
    }

    public Conversation() {}

    public Conversation(UUID initiatorUserId, LocalDateTime expiresAt) {
        this.initiatorUserId = initiatorUserId;
        this.expiresAt = expiresAt;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getInitiatorUserId() {
        return initiatorUserId;
    }

    public void setInitiatorUserId(UUID initiatorUserId) {
        this.initiatorUserId = initiatorUserId;
    }

    public ConversationStatus getStatus() {
        return status;
    }

    public void setStatus(ConversationStatus status) {
        this.status = status;
    }

    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(LocalDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt);
    }

    public boolean isActive() {
        return status == ConversationStatus.ACTIVE && !isExpired();
    }

    public boolean isDeleted() {
        return status == ConversationStatus.DELETED;
    }
}
