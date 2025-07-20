package com.example.securemessaging.dto;

import com.example.securemessaging.entity.Message;
import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.LocalDateTime;
import java.util.UUID;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class MessageResponse {

    private UUID id;
    private String ciphertext;
    private String nonce;
    private String tag;
    private LocalDateTime createdAt;
    private LocalDateTime expiresAt;
    private LocalDateTime readAt;
    private boolean consumed;

    public MessageResponse() {}

    public MessageResponse(Message message) {
        this.id = message.getId();
        this.ciphertext = message.getCiphertext();
        this.nonce = message.getNonce();
        this.tag = message.getTag();
        this.createdAt = message.getCreatedAt();
        this.expiresAt = message.getExpiresAt();
        this.readAt = message.getReadAt();
        this.consumed = message.isConsumed();
    }

    public static MessageResponse fromMessage(Message message) {
        return new MessageResponse(message);
    }

    public static MessageResponse createResponse(UUID id) {
        MessageResponse response = new MessageResponse();
        response.setId(id);
        return response;
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
}