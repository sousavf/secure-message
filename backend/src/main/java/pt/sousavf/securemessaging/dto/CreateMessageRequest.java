package pt.sousavf.securemessaging.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import pt.sousavf.securemessaging.entity.Message;

public class CreateMessageRequest {

    @NotBlank(message = "Ciphertext is required")
    @Size(max = 100000, message = "Ciphertext too large")
    private String ciphertext;

    @NotBlank(message = "Nonce is required")
    @Size(max = 255, message = "Nonce too large")
    private String nonce;

    @Size(max = 255, message = "Tag too large")
    private String tag;

    private Message.MessageType messageType = Message.MessageType.TEXT;

    // File metadata (for FILE/IMAGE messages)
    @Size(max = 255, message = "File name too large")
    private String fileName;

    private Integer fileSize;

    @Size(max = 100, message = "MIME type too large")
    private String fileMimeType;

    public CreateMessageRequest() {}

    public CreateMessageRequest(String ciphertext, String nonce, String tag) {
        this.ciphertext = ciphertext;
        this.nonce = nonce;
        this.tag = tag;
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

    public Message.MessageType getMessageType() {
        return messageType;
    }

    public void setMessageType(Message.MessageType messageType) {
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
}