package pt.sousavf.securemessaging.dto;

import jakarta.validation.constraints.NotBlank;

public class RegisterDeviceTokenRequest {

    @NotBlank(message = "APNs token cannot be blank")
    private String apnsToken;

    // Constructors
    public RegisterDeviceTokenRequest() {
    }

    public RegisterDeviceTokenRequest(String apnsToken) {
        this.apnsToken = apnsToken;
    }

    // Getters and Setters
    public String getApnsToken() {
        return apnsToken;
    }

    public void setApnsToken(String apnsToken) {
        this.apnsToken = apnsToken;
    }
}
