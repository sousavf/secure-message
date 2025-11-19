package pt.sousavf.securemessaging.dto;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Response DTO for conversation participant status
 */
public class ParticipantStatusResponse {
    private UUID conversationId;
    private String deviceId;
    private boolean isInitiator;
    private boolean isActive;
    private LocalDateTime joinedAt;
    private LocalDateTime departedAt;

    public ParticipantStatusResponse() {}

    public ParticipantStatusResponse(UUID conversationId, String deviceId, boolean isInitiator,
                                    boolean isActive, LocalDateTime joinedAt, LocalDateTime departedAt) {
        this.conversationId = conversationId;
        this.deviceId = deviceId;
        this.isInitiator = isInitiator;
        this.isActive = isActive;
        this.joinedAt = joinedAt;
        this.departedAt = departedAt;
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

    public boolean isActive() {
        return isActive;
    }

    public void setActive(boolean active) {
        isActive = active;
    }

    public LocalDateTime getJoinedAt() {
        return joinedAt;
    }

    public void setJoinedAt(LocalDateTime joinedAt) {
        this.joinedAt = joinedAt;
    }

    public LocalDateTime getDepartedAt() {
        return departedAt;
    }

    public void setDepartedAt(LocalDateTime departedAt) {
        this.departedAt = departedAt;
    }
}
