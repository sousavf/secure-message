package pt.sousavf.securemessaging.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Max;

public class CreateMessageRequest {

    @NotBlank(message = "Ciphertext is required")
    @Size(max = 100000, message = "Ciphertext too large")
    private String ciphertext;

    @NotBlank(message = "Nonce is required")
    @Size(max = 255, message = "Nonce too large")
    private String nonce;

    @Size(max = 255, message = "Tag too large")
    private String tag;

    @Min(value = 5, message = "TTL must be at least 5 minutes")
    @Max(value = 2880, message = "TTL must not exceed 48 hours (2880 minutes)")
    private Integer ttlMinutes;

    public CreateMessageRequest() {}

    public CreateMessageRequest(String ciphertext, String nonce, String tag) {
        this.ciphertext = ciphertext;
        this.nonce = nonce;
        this.tag = tag;
    }

    public CreateMessageRequest(String ciphertext, String nonce, String tag, Integer ttlMinutes) {
        this.ciphertext = ciphertext;
        this.nonce = nonce;
        this.tag = tag;
        this.ttlMinutes = ttlMinutes;
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

    public Integer getTtlMinutes() {
        return ttlMinutes;
    }

    public void setTtlMinutes(Integer ttlMinutes) {
        this.ttlMinutes = ttlMinutes;
    }
}