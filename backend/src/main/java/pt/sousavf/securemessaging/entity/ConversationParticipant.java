package pt.sousavf.securemessaging.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Tracks devices/participants in a conversation
 * Allows detection when a device leaves or deletes the conversation
 */
@Entity
@Table(name = "conversation_participants", indexes = {
    @Index(name = "idx_participant_conversation", columnList = "conversation_id"),
    @Index(name = "idx_participant_device", columnList = "conversation_id, device_id")
})
public class ConversationParticipant {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @Column(name = "conversation_id", nullable = false)
    private UUID conversationId;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    @Column(name = "is_initiator", nullable = false)
    private boolean isInitiator = false;

    @Column(name = "departed_at")
    private LocalDateTime departedAt;

    @Column(name = "link_consumed_at")
    private LocalDateTime linkConsumedAt;

    @CreationTimestamp
    @Column(name = "joined_at", nullable = false, updatable = false)
    private LocalDateTime joinedAt;

    public ConversationParticipant() {}

    public ConversationParticipant(UUID conversationId, String deviceId, boolean isInitiator) {
        this.conversationId = conversationId;
        this.deviceId = deviceId;
        this.isInitiator = isInitiator;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getConversationId() {
        return conversationId;
    }

    public void setConversationId(UUID conversationId) {
        this.conversationId = conversationId;
    }

    public String getDeviceId() {
        return deviceId;
    }

    public void setDeviceId(String deviceId) {
        this.deviceId = deviceId;
    }

    public boolean isInitiator() {
        return isInitiator;
    }

    public void setInitiator(boolean initiator) {
        isInitiator = initiator;
    }

    public LocalDateTime getDepartedAt() {
        return departedAt;
    }

    public void setDepartedAt(LocalDateTime departedAt) {
        this.departedAt = departedAt;
    }

    public LocalDateTime getLinkConsumedAt() {
        return linkConsumedAt;
    }

    public void setLinkConsumedAt(LocalDateTime linkConsumedAt) {
        this.linkConsumedAt = linkConsumedAt;
    }

    public LocalDateTime getJoinedAt() {
        return joinedAt;
    }

    public void setJoinedAt(LocalDateTime joinedAt) {
        this.joinedAt = joinedAt;
    }

    /**
     * Check if this participant is still active (hasn't left)
     */
    public boolean isActive() {
        return departedAt == null;
    }

    /**
     * Mark this participant as having departed
     */
    public void markAsDeparted() {
        this.departedAt = LocalDateTime.now();
    }

    /**
     * Mark the conversation link as consumed by this participant
     */
    public void markLinkAsConsumed() {
        this.linkConsumedAt = LocalDateTime.now();
    }

    /**
     * Check if this is a secondary participant (not initiator and link was consumed)
     */
    public boolean isSecondaryParticipant() {
        return !isInitiator && linkConsumedAt != null;
    }
}
