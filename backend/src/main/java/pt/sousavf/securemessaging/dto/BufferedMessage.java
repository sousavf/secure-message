package pt.sousavf.securemessaging.dto;

import pt.sousavf.securemessaging.entity.Message;

import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;

/**
 * Message stored temporarily in Redis queue before async processing
 */
public class BufferedMessage implements Serializable {

    private UUID serverId;          // Server-assigned message ID
    private UUID conversationId;
    private String deviceId;
    private String ciphertext;
    private String nonce;
    private String tag;
    private Message.MessageType messageType;
    private Instant queuedAt;
    private int retryCount;

    // File metadata (for FILE/IMAGE messages)
    private String fileName;
    private Integer fileSize;
    private String fileMimeType;

    public BufferedMessage() {
        this.retryCount = 0;
    }

    public BufferedMessage(UUID serverId, UUID conversationId, String deviceId,
                          String ciphertext, String nonce, String tag,
                          Message.MessageType messageType, Instant queuedAt) {
        this.serverId = serverId;
        this.conversationId = conversationId;
        this.deviceId = deviceId;
        this.ciphertext = ciphertext;
        this.nonce = nonce;
        this.tag = tag;
        this.messageType = messageType;
        this.queuedAt = queuedAt;
        this.retryCount = 0;
    }

    // Getters and setters
    public UUID getServerId() { return serverId; }
    public void setServerId(UUID serverId) { this.serverId = serverId; }

    public UUID getConversationId() { return conversationId; }
    public void setConversationId(UUID conversationId) { this.conversationId = conversationId; }

    public String getDeviceId() { return deviceId; }
    public void setDeviceId(String deviceId) { this.deviceId = deviceId; }

    public String getCiphertext() { return ciphertext; }
    public void setCiphertext(String ciphertext) { this.ciphertext = ciphertext; }

    public String getNonce() { return nonce; }
    public void setNonce(String nonce) { this.nonce = nonce; }

    public String getTag() { return tag; }
    public void setTag(String tag) { this.tag = tag; }

    public Message.MessageType getMessageType() { return messageType; }
    public void setMessageType(Message.MessageType messageType) { this.messageType = messageType; }

    public Instant getQueuedAt() { return queuedAt; }
    public void setQueuedAt(Instant queuedAt) { this.queuedAt = queuedAt; }

    public int getRetryCount() { return retryCount; }
    public void setRetryCount(int retryCount) { this.retryCount = retryCount; }

    public String getFileName() { return fileName; }
    public void setFileName(String fileName) { this.fileName = fileName; }

    public Integer getFileSize() { return fileSize; }
    public void setFileSize(Integer fileSize) { this.fileSize = fileSize; }

    public String getFileMimeType() { return fileMimeType; }
    public void setFileMimeType(String fileMimeType) { this.fileMimeType = fileMimeType; }
}
