package pt.sousavf.securemessaging.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Response when message is successfully queued in Redis
 */
public class MessageBufferedResponse {

    private UUID serverId;          // Server-assigned message ID
    private String status;          // "QUEUED_FOR_PROCESSING"
    private Instant queuedAt;       // When message entered Redis queue

    public MessageBufferedResponse() {
    }

    public MessageBufferedResponse(UUID serverId, String status, Instant queuedAt) {
        this.serverId = serverId;
        this.status = status;
        this.queuedAt = queuedAt;
    }

    public UUID getServerId() {
        return serverId;
    }

    public void setServerId(UUID serverId) {
        this.serverId = serverId;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getQueuedAt() {
        return queuedAt;
    }

    public void setQueuedAt(Instant queuedAt) {
        this.queuedAt = queuedAt;
    }
}
