package pt.sousavf.securemessaging.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public class FileUploadRequest {

    @NotBlank(message = "Ciphertext cannot be blank")
    @Size(max = 15000000, message = "Ciphertext too large") // ~15MB to account for base64 encoding
    private String ciphertext;

    @NotBlank(message = "Nonce cannot be blank")
    @Size(max = 255, message = "Nonce too large")
    private String nonce;

    @NotBlank(message = "Tag cannot be blank")
    @Size(max = 255, message = "Tag too large")
    private String tag;

    @NotBlank(message = "File name cannot be blank")
    @Size(max = 255, message = "File name too large")
    private String fileName;

    @NotNull(message = "File size cannot be null")
    private Integer fileSize;

    @NotBlank(message = "MIME type cannot be blank")
    @Size(max = 100, message = "MIME type too large")
    private String mimeType;

    // Constructors
    public FileUploadRequest() {}

    public FileUploadRequest(String ciphertext, String nonce, String tag, String fileName, Integer fileSize, String mimeType) {
        this.ciphertext = ciphertext;
        this.nonce = nonce;
        this.tag = tag;
        this.fileName = fileName;
        this.fileSize = fileSize;
        this.mimeType = mimeType;
    }

    // Getters and Setters
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

    public String getMimeType() {
        return mimeType;
    }

    public void setMimeType(String mimeType) {
        this.mimeType = mimeType;
    }
}
