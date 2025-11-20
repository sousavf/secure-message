package pt.sousavf.securemessaging.controller;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pt.sousavf.securemessaging.dto.RegisterDeviceTokenRequest;
import pt.sousavf.securemessaging.entity.DeviceToken;
import pt.sousavf.securemessaging.service.DeviceTokenService;

@RestController
@RequestMapping("/api/devices")
@CrossOrigin(origins = {"http://localhost:3000", "https://localhost:3000"})
public class DeviceTokenController {

    private static final Logger logger = LoggerFactory.getLogger(DeviceTokenController.class);

    private final DeviceTokenService deviceTokenService;

    public DeviceTokenController(DeviceTokenService deviceTokenService) {
        this.deviceTokenService = deviceTokenService;
    }

    /**
     * Register or update APNs token for a device
     * POST /api/devices/token
     */
    @PostMapping("/token")
    public ResponseEntity<?> registerDeviceToken(
            @Valid @RequestBody RegisterDeviceTokenRequest request,
            @RequestHeader(value = "X-Device-ID", required = true) String deviceId) {
        try {
            if (deviceId == null || deviceId.isBlank()) {
                logger.warn("Device ID is missing in request");
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(new ErrorMessage("Device ID is required"));
            }

            logger.info("Registering APNs token for device: {}", deviceId);
            DeviceToken token = deviceTokenService.registerToken(deviceId, request.getApnsToken());

            return ResponseEntity.status(HttpStatus.CREATED).body(new TokenResponse(
                    token.getId().toString(),
                    token.getDeviceId(),
                    "Token registered successfully"
            ));
        } catch (Exception e) {
            logger.error("Error registering device token", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ErrorMessage("Failed to register device token"));
        }
    }

    /**
     * Unregister device tokens (called on logout)
     * POST /api/devices/logout
     */
    @PostMapping("/logout")
    public ResponseEntity<?> logoutDevice(
            @RequestHeader(value = "X-Device-ID", required = true) String deviceId) {
        try {
            if (deviceId == null || deviceId.isBlank()) {
                logger.warn("Device ID is missing in logout request");
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(new ErrorMessage("Device ID is required"));
            }

            logger.info("Logging out device: {}", deviceId);
            deviceTokenService.removeAllTokens(deviceId);

            return ResponseEntity.ok(new SuccessMessage("Device logged out successfully"));
        } catch (Exception e) {
            logger.error("Error logging out device", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ErrorMessage("Failed to logout device"));
        }
    }

    // DTO classes for responses
    public static class TokenResponse {
        private final String tokenId;
        private final String deviceId;
        private final String message;

        public TokenResponse(String tokenId, String deviceId, String message) {
            this.tokenId = tokenId;
            this.deviceId = deviceId;
            this.message = message;
        }

        public String getTokenId() {
            return tokenId;
        }

        public String getDeviceId() {
            return deviceId;
        }

        public String getMessage() {
            return message;
        }
    }

    public static class SuccessMessage {
        private final String message;

        public SuccessMessage(String message) {
            this.message = message;
        }

        public String getMessage() {
            return message;
        }
    }

    public static class ErrorMessage {
        private final String message;

        public ErrorMessage(String message) {
            this.message = message;
        }

        public String getMessage() {
            return message;
        }
    }
}
