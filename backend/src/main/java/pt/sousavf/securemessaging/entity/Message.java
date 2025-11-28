package pt.sousavf.securemessaging.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.hibernate.annotations.CreationTimestamp;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.time.LocalDateTime;
import java.util.UUID;

@JsonIgnoreProperties(ignoreUnknown = true)
@Entity
@Table(name = "messages", indexes = {
    // Pagination queries: conversation + created_at for efficient cursor-based pagination
    @Index(name = "idx_msg_conv_created", columnList = "conversation_id, created_at DESC"),
    // Cleanup queries: expires_at for efficient TTL expiration detection
    @Index(name = "idx_msg_expires_at", columnList = "expires_at"),
    // Filtering: consumed status
    @Index(name = "idx_msg_consumed", columnList = "consumed"),
    // Sorting and filtering
    @Index(name = "idx_msg_created_at", columnList = "createdAt"),
    @Index(name = "idx_msg_conversation_id", columnList = "conversation_id")
})
public class Message {

    public enum MessageType {
        TEXT,
        STICKER,
        IMAGE,
        FILE
    }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @NotBlank(message = "Ciphertext cannot be blank")
    @Size(max = 15000000, message = "Ciphertext too large") // ~15MB to account for base64 encoding overhead
    @Column(name = "ciphertext", nullable = false, columnDefinition = "TEXT")
    private String ciphertext;

    @NotBlank(message = "Nonce cannot be blank")
    @Size(max = 255, message = "Nonce too large")
    @Column(name = "nonce", nullable = false)
    private String nonce;

    @Size(max = 255, message = "Tag too large")
    @Column(name = "tag")
    private String tag;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @NotNull
    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "read_at")
    private LocalDateTime readAt;

    @Column(name = "consumed", nullable = false)
    private boolean consumed = false;

    @Column(name = "sender_device_id")
    private String senderDeviceId;

    @Column(name = "conversation_id")
    private UUID conversationId;

    @Enumerated(EnumType.STRING)
    @Column(name = "message_type", nullable = false)
    private MessageType messageType = MessageType.TEXT;

    // File metadata (only populated for FILE type messages)
    @Column(name = "file_name")
    @Size(max = 255, message = "File name too large")
    private String fileName;

    @Column(name = "file_size")
    private Integer fileSize;

    @Column(name = "file_mime_type")
    @Size(max = 100, message = "MIME type too large")
    private String fileMimeType;

    @Column(name = "file_url")
    @Size(max = 2048, message = "File URL too large")
    private String fileUrl;

    public Message() {}

    public Message(String ciphertext, String nonce, String tag, LocalDateTime expiresAt) {
        this.ciphertext = ciphertext;
        this.nonce = nonce;
        this.tag = tag;
        this.expiresAt = expiresAt;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getCiphertext() {
        return ciphertext;
    }

    public void setCiphertext(String ciphertext) {
        this.ciphertext = ciphertext;
    }

    public String getNonce() {
        return nonce;
    }

    public void setNonce(String nonce) {
        this.nonce = nonce;
    }

    public String getTag() {
        return tag;
    }

    public void setTag(String tag) {
        this.tag = tag;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(LocalDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public LocalDateTime getReadAt() {
        return readAt;
    }

    public void setReadAt(LocalDateTime readAt) {
        this.readAt = readAt;
    }

    public boolean isConsumed() {
        return consumed;
    }

    public void setConsumed(boolean consumed) {
        this.consumed = consumed;
    }

    public void markAsConsumed() {
        this.consumed = true;
        this.readAt = LocalDateTime.now();
    }

    public boolean isExpired() {
        return LocalDateTime.now(java.time.ZoneId.of("UTC")).isAfter(expiresAt);
    }

    public String getSenderDeviceId() {
        return senderDeviceId;
    }

    public void setSenderDeviceId(String senderDeviceId) {
        this.senderDeviceId = senderDeviceId;
    }

    public UUID getConversationId() {
        return conversationId;
    }

    public void setConversationId(UUID conversationId) {
        this.conversationId = conversationId;
    }

    public MessageType getMessageType() {
        return messageType;
    }

    public void setMessageType(MessageType messageType) {
        this.messageType = messageType;
    }

    public String getFileName() {
        return fileName;
    }

    public void setFileName(String fileName) {
        this.fileName = fileName;
    }

    public Integer getFileSize() {
        return fileSize;
    }

    public void setFileSize(Integer fileSize) {
        this.fileSize = fileSize;
    }

    public String getFileMimeType() {
        return fileMimeType;
    }

    public void setFileMimeType(String fileMimeType) {
        this.fileMimeType = fileMimeType;
    }

    public String getFileUrl() {
        return fileUrl;
    }

    public void setFileUrl(String fileUrl) {
        this.fileUrl = fileUrl;
    }
}