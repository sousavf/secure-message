# APNs Certificate Setup Guide

## Prerequisites

- Apple Developer Program membership ($99/year)
- Xcode 14+ with iOS 17.5+ SDK
- Bundle ID for your app: `pt.sousavf.SafeWhisper`

## Step 1: Generate APNs Certificate

### 1.1 Create Certificate Signing Request (CSR)

On your Mac:
1. Open Keychain Access
2. Go to Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
3. Email Address: your@example.com
4. Common Name: Safe Whisper APNs
5. Request is: Saved to disk
6. Save as `CertificateSigningRequest.certSigningRequest`

### 1.2 Create App ID (if not exists)

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles → Identifiers
3. Click "+" to register new App ID
4. Choose "App IDs"
5. Bundle ID: `pt.sousavf.SafeWhisper`
6. Enable "Push Notifications" capability
7. Click "Register"

### 1.3 Create APNs Certificate

1. In Apple Developer Portal → Certificates
2. Click "+" to create new certificate
3. Select "Apple Push Notification service SSL (Sandbox & Production)"
4. Select your App ID (`pt.sousavf.SafeWhisper`)
5. Upload the CSR from step 1.1
6. Download the certificate as `aps.cer`

### 1.4 Export Private Key

1. In Keychain Access, find the certificate you just created
2. Right-click → Export
3. Save as `aps.p12` with password (remember the password)

### 1.5 Convert to PKCS8 Format

Open Terminal:

```bash
# Convert .p12 to PEM (combine cert + private key)
openssl pkcs12 -in aps.p12 -out aps.pem -nodes -clcerts

# Convert PEM to PKCS8 format (required by Pushy)
openssl pkcs8 -topk8 -inform PEM -outform PEM -in aps.pem -out AuthKey.p8 -nocrypt
```

Result: `AuthKey.p8` file

## Step 2: Get APNs Credentials

In Apple Developer Portal → Account:

1. **Key ID:**
   - Go to Certificates → Create new "App Store Connect API Key"
   - Or find existing Apple Push Services certificate → Key ID shown in details
   - Format: 10-character alphanumeric (e.g., `ABC123XYZ1`)

2. **Team ID:**
   - Go to Account → Membership
   - Team ID is 10-character code (e.g., `ABC123XYZ1`)

## Step 3: Configure Backend

### 3.1 Store APNs Key

Copy `AuthKey.p8` to your server:

```bash
# Production server example
scp AuthKey.p8 user@your-backend.com:/etc/secrets/AuthKey.p8
ssh user@your-backend.com chmod 600 /etc/secrets/AuthKey.p8
```

### 3.2 Set Environment Variables

```bash
export APNS_ENABLED=true
export APNS_KEY_ID=ABC123XYZ1          # Your Key ID
export APNS_TEAM_ID=ABC123XYZ1         # Your Team ID
export APNS_KEY_PATH=/etc/secrets/AuthKey.p8
export APNS_TOPIC=pt.sousavf.SafeWhisper  # Your Bundle ID
```

### 3.3 For Docker Deployment

Add to your Dockerfile or docker-compose:

```dockerfile
# Copy APNs key into container
COPY AuthKey.p8 /etc/secrets/AuthKey.p8
RUN chmod 600 /etc/secrets/AuthKey.p8
```

Or in docker-compose.yml:

```yaml
environment:
  - APNS_ENABLED=true
  - APNS_KEY_ID=${APNS_KEY_ID}
  - APNS_TEAM_ID=${APNS_TEAM_ID}
  - APNS_KEY_PATH=/etc/secrets/AuthKey.p8
volumes:
  - ./AuthKey.p8:/etc/secrets/AuthKey.p8:ro
```

## Step 4: iOS Configuration

### 4.1 Xcode Capabilities

1. Open SecureMessagingApp.xcodeproj in Xcode
2. Select target "Safe Whisper"
3. Go to Signing & Capabilities
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" → Check "Remote notifications"

### 4.2 Update Info.plist

Xcode automatically adds:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### 4.3 Provisioning Profile

1. In Xcode: Signing & Capabilities → "Safe Whisper" target
2. Update provisioning profile to include Push Notifications entitlement
3. Profile should include APNs services

## Step 5: Testing

### Test Token Registration

```bash
# Get APNs token from device console (or logs)
# Device must run iOS 17.5+, have app installed, and grant notification permission

# Test backend token registration
curl -X POST https://your-backend.com/api/devices/token \
  -H "X-Device-ID: test-device-uuid" \
  -H "Content-Type: application/json" \
  -d '{"apnsToken":"xxxxxxx..."}'

# Expected response (201 Created):
{
  "tokenId": "uuid",
  "deviceId": "test-device-uuid",
  "message": "Token registered successfully"
}
```

### Test Push Delivery

1. Build and run app on real device
2. Grant notification permission when prompted
3. Check backend logs for token registration:
   ```
   [DEBUG] AppDelegate - Registered for remote notifications, token: XXXX...
   ```
4. Send test message from other participant
5. Check backend logs for push sent:
   ```
   [DEBUG] ApnsPushService - Sending silent push to token: XXXX...
   ```
6. Check iOS device - should receive message soon
7. Check iOS logs:
   ```
   [DEBUG] AppDelegate - Received remote notification
   [DEBUG] ConversationDetailView - Push received for our conversation, polling immediately
   ```

### Verify Encryption

1. Send message from one device
2. Other device should:
   - Receive push notification (silent)
   - Immediately poll for messages
   - Decrypt message using shared encryption key
   - Display in UI

### Monitor APNs Status

```bash
# Watch backend logs
tail -f /var/log/backend/app.log | grep -E "ApnsPushService|DeviceToken"

# Check token database
psql -U postgres -d privileged_messaging \
  -c "SELECT device_id, active, updated_at FROM device_tokens ORDER BY updated_at DESC LIMIT 10;"
```

## Troubleshooting

### "BadDeviceToken" Error

- Token expired (user deleted/reinstalled app)
- Token belongs to different app
- Token from sandbox, but cert is production (or vice versa)

**Solution:** Backend automatically deactivates bad tokens

### Push Not Arriving

1. Verify APNs certificate is valid:
   ```bash
   openssl x509 -in AuthKey.p8 -text -noout
   ```

2. Check Team ID and Key ID are correct:
   ```bash
   # Backend should log during initialization
   grep "Initializing APNs" /var/log/backend/app.log
   ```

3. Verify bundle ID matches:
   - Xcode: Safe Whisper target → General → Bundle Identifier
   - APNs key: application.yml → `apns.topic`

4. Check network connectivity:
   ```bash
   # Can backend reach APNs?
   nc -zv api.push.apple.com 443
   ```

### Push Enabled But Not Working

- Check if user granted notification permission
- Verify device is online
- Check iOS logs: `[DEBUG] AppDelegate - Received remote notification`

### Certificate Expiration

APNs certificates valid for 1 year.

**Before expiration:**
1. Create new certificate (steps 1.2-1.5)
2. Update `AuthKey.p8` on server
3. Restart backend service
4. No client-side changes needed

## Security Best Practices

1. **Protect Private Key:**
   - Store `AuthKey.p8` with restrictive permissions (600)
   - Never commit to git
   - Use secrets management (AWS Secrets Manager, Kubernetes Secrets, etc.)

2. **Rotate Keys Regularly:**
   - Generate new APNs certificate annually
   - Before old certificate expires

3. **Monitor Token Changes:**
   - Log all token registrations
   - Alert on unusual patterns (too many tokens from single device)

4. **Never Log Tokens:**
   - Only log first 16 characters of token
   - Never log full token in production

## Renewal Checklist (Annual)

- [ ] Check certificate expiration date
- [ ] 30 days before: Start renewal process
- [ ] Generate new CSR and certificate
- [ ] Export new `AuthKey.p8`
- [ ] Test with staging environment first
- [ ] Update production backend
- [ ] Monitor for any issues
- [ ] Old certificate can be revoked after 7 days

## References

- [Apple Push Notification service](https://developer.apple.com/documentation/usernotifications)
- [Generating APNs Certificates](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/generating_authentication_tokens_for_apple_push_notification)
- [PKCS8 Format](https://en.wikipedia.org/wiki/PKCS_8)
