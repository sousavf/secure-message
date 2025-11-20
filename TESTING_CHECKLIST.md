# Testing Checklist for Hybrid Push Implementation

## Pre-Testing Setup

### Backend Prerequisites

- [ ] JDK 17+ installed
- [ ] Maven 3.8+ installed
- [ ] PostgreSQL running locally or configured in application.yml
- [ ] Project builds without errors: `mvn clean package`

### iOS Prerequisites

- [ ] Xcode 14+ installed
- [ ] iOS 17.5+ device for testing (push won't work on simulator)
- [ ] iOS device connected and trusted
- [ ] Apple Developer Program account

### APNs Prerequisites

- [ ] APNs certificate obtained from Apple Developer Portal
- [ ] AuthKey.p8 file generated and available
- [ ] Team ID noted
- [ ] Key ID noted
- [ ] Bundle ID = pt.sousavf.SafeWhisper confirmed

## Phase 1: Backend Unit Tests

### Compile & Build

```bash
cd backend
mvn clean compile
```

- [ ] No compilation errors
- [ ] All new classes found
- [ ] Dependencies resolved (Pushy, Guava)

### Database Migration

```bash
# Start fresh database
psql -U postgres -c "DROP DATABASE IF EXISTS privileged_messaging;"
psql -U postgres -c "CREATE DATABASE privileged_messaging;"
```

- [ ] Database created
- [ ] Tables auto-created by Hibernate
- [ ] `device_tokens` table exists with proper schema

### Verify New Services

```bash
mvn test -Dtest=ApnsPushServiceTest
mvn test -Dtest=DeviceTokenServiceTest
```

- [ ] All service tests pass
- [ ] No null pointer exceptions
- [ ] Proper error handling

## Phase 2: Backend Integration Tests

### Start Backend Server

```bash
APNS_ENABLED=false mvn spring-boot:run
```

- [ ] Server starts on port 8687
- [ ] No initialization errors
- [ ] APNs disabled gracefully (no certificate errors)

### Test Device Token API

```bash
# Register token
curl -X POST http://localhost:8687/api/devices/token \
  -H "X-Device-ID: test-device-uuid" \
  -H "Content-Type: application/json" \
  -d '{"apnsToken":"test-token-1234567890abcdef"}'
```

- [ ] Returns 201 Created
- [ ] Response includes tokenId, deviceId, message
- [ ] No errors in backend logs

### Verify Database

```bash
psql -U privileged_user -d privileged_messaging \
  -c "SELECT device_id, active FROM device_tokens;"
```

- [ ] Token stored in database
- [ ] marked as active: true
- [ ] Device ID matches request header

### Test Token Update

Register same deviceId with new token:

```bash
curl -X POST http://localhost:8687/api/devices/token \
  -H "X-Device-ID: test-device-uuid" \
  -H "Content-Type: application/json" \
  -d '{"apnsToken":"new-token-abcdefghijk"}'
```

- [ ] New token created
- [ ] Old token marked as inactive
- [ ] Only one active token per device

### Test Logout

```bash
curl -X POST http://localhost:8687/api/devices/logout \
  -H "X-Device-ID: test-device-uuid"
```

- [ ] Returns 200 OK
- [ ] All tokens for device removed

## Phase 3: iOS Unit Tests

### Build iOS Project

```bash
cd SecureMessagingApp
xcodebuild build -scheme "Safe Whisper" -configuration Debug
```

- [ ] No compilation errors
- [ ] AppDelegate initializes
- [ ] PushNotificationService accessible
- [ ] All imports resolve

### Verify Files Added

- [ ] `AppDelegate.swift` exists
- [ ] `PushNotificationService.swift` exists
- [ ] Both files have correct imports

### Check Capabilities

1. Open SecureMessagingApp.xcodeproj in Xcode
2. Select "Safe Whisper" target
3. Go to Signing & Capabilities

- [ ] "Push Notifications" capability present
- [ ] "Remote notifications" in Background Modes enabled
- [ ] No warnings about signing

### Verify Info.plist

```bash
plutil -p SecureMessagingApp/Info.plist | grep -A2 "UIBackgroundModes"
```

- [ ] UIBackgroundModes contains "remote-notification"

## Phase 4: End-to-End Testing (Without APNs)

### Start Backend with APNs Disabled

```bash
APNS_ENABLED=false mvn spring-boot:run
```

### Build and Run iOS App on Device

1. Connect iOS device
2. Select device in Xcode
3. Click Run

- [ ] App builds and installs successfully
- [ ] App launches without crashes
- [ ] No runtime errors in console

### Test Polling (Baseline)

1. Send message from Device A
2. Wait and observe Device B

- [ ] Message appears within 5-10 seconds
- [ ] Message decrypts correctly
- [ ] No errors in iOS logs

### Verify Polling Rate

Monitor backend logs:

```bash
# Look for message fetch requests
tail -f /var/log/spring-boot.log | grep "getConversationMessages"
```

- [ ] Requests arrive approximately every 5 seconds
- [ ] Timestamps show correct intervals
- [ ] No excessive polling

### Test Multiple Messages

Send 5+ messages rapidly from Device A

- [ ] All messages appear on Device B
- [ ] None are skipped or duplicated
- [ ] Correct order maintained
- [ ] Timestamps accurate

## Phase 5: APNs Configuration Testing

### Copy APNs Key to Backend

```bash
cp AuthKey.p8 /etc/secrets/AuthKey.p8
chmod 600 /etc/secrets/AuthKey.p8
```

- [ ] File copied successfully
- [ ] Permissions set to 600

### Start Backend with APNs Enabled

```bash
export APNS_ENABLED=true
export APNS_KEY_ID=YOUR_KEY_ID
export APNS_TEAM_ID=YOUR_TEAM_ID
export APNS_KEY_PATH=/etc/secrets/AuthKey.p8
export APNS_TOPIC=pt.sousavf.SafeWhisper

mvn spring-boot:run
```

Check logs:

```
[INFO] ApnsConfig - Initializing APNs service
[INFO] ApnsPushService - Initializing APNs client with team ID: ...
```

- [ ] APNs service initializes without errors
- [ ] No certificate errors
- [ ] Connection established successfully

## Phase 6: iOS Push Registration Testing

### Rebuild iOS App

1. Ensure device has notification permission enabled
2. Rebuild iOS app

```bash
xcodebuild build -scheme "Safe Whisper" -configuration Debug -destination "generic/platform=iOS"
```

- [ ] App builds successfully
- [ ] No warnings about capabilities

### Run App on Device

1. Install app on device
2. When prompted, grant notification permission
3. Check backend logs:

```bash
grep "Registered for remote notifications" /var/log/spring-boot.log
# or check iOS console
```

- [ ] AppDelegate logs token received
- [ ] Token sent to backend registration endpoint
- [ ] Backend logs successful registration

### Verify Token Registered

```bash
psql -U privileged_user -d privileged_messaging \
  -c "SELECT device_id, apns_token, active FROM device_tokens ORDER BY updated_at DESC LIMIT 1;"
```

- [ ] Token stored in database
- [ ] Matches token from iOS logs
- [ ] active = true

## Phase 7: End-to-End Push Testing

### Send Message with Push Notification

1. Device A: Open conversation with Device B
2. Device A: Send message "Test push message"
3. Device B: Keep app in foreground
4. Backend logs should show:

```
[DEBUG] ApnsPushService - Sending silent push to token: XXXX...
[DEBUG] ApnsPushService - Push notification accepted
```

- [ ] Push sent successfully
- [ ] Status shows "accepted"

### Verify iOS Receives Push

Check iOS device logs:

```
[DEBUG] AppDelegate - Received remote notification
[DEBUG] AppDelegate - Silent push received
```

- [ ] Push notification received
- [ ] Silent notification (not shown to user)
- [ ] No errors in handling

### Verify Message Fetched

Check iOS console:

```
[DEBUG] ConversationDetailView - Push received for our conversation, polling immediately
[DEBUG] ConversationDetailView - Received X new messages
```

- [ ] Push listener triggered
- [ ] Conversation hash matched
- [ ] Message fetched immediately
- [ ] Message displayed in UI

### Verify Message Content

1. Check Device B UI
2. Message should appear within 1 second of send

- [ ] Message visible
- [ ] Content correct
- [ ] Decrypted properly
- [ ] Timestamp accurate
- [ ] Sender marked correctly

## Phase 8: Adaptive Polling Testing

### Verify Polling Interval Change

1. Send multiple messages
2. Monitor polling frequency before and after push

**Without Push (all disabled):**

```bash
grep "getConversationMessages" /var/log/spring-boot.log | \
  awk '{print $1, $2}' | tail -20
```

- [ ] Requests every 5 seconds

**With Push (enabled and working):**

- [ ] Requests every 30 seconds
- [ ] Immediate poll on push receipt
- [ ] Falls back to 5s if push disabled

### Test Push Failure Fallback

1. With APNs enabled and working
2. "Disable" push (set APNS_ENABLED=false)
3. Restart backend
4. Send message from Device A
5. Observe Device B

- [ ] Message still arrives via polling
- [ ] Polling interval returns to 5 seconds
- [ ] No message loss

## Phase 9: Error Handling Testing

### Test Invalid Token Response

1. Manually insert invalid token in database
2. Send message
3. Check backend logs

```
[WARN] ApnsPushService - Push notification rejected: BadDeviceToken
[INFO] ApnsPushService - Removing invalid device token
```

- [ ] Token marked as invalid
- [ ] Automatic deactivation
- [ ] Subsequent polls still work

### Test Device Switch

1. Uninstall app from Device A
2. Install on Device B with same logical device ID
3. Send test message
4. Check database

```bash
psql -U privileged_user -d privileged_messaging \
  -c "SELECT device_id, active FROM device_tokens WHERE device_id='...';"
```

- [ ] Old token marked inactive
- [ ] New token marked active
- [ ] Only one active token

### Test Logout

1. Call logout endpoint
2. Check database

```bash
psql -U privileged_user -d privileged_messaging \
  -c "SELECT COUNT(*) FROM device_tokens WHERE device_id='test-device';"
```

- [ ] All tokens removed
- [ ] Database clean

## Phase 10: Performance Testing

### Message Latency Measurement

Use timestamp comparison:

1. Record send time on Device A (now)
2. Record arrival time on Device B (when displayed)
3. Calculate delta

**Expected results:**
- [ ] Average latency < 1 second with push
- [ ] Message arrives within 5 seconds without push
- [ ] Max latency < 2 seconds (99th percentile)

### Load Testing

Send 100 messages rapidly:

```
for i in {1..100}; do
  curl -X POST http://localhost:8687/api/conversations/{id}/messages \
    -H "X-Device-ID: test-device" \
    -H "Content-Type: application/json" \
    -d "{...encrypted message...}"
  sleep 0.1
done
```

Monitor metrics:

```bash
# Check backend memory
jps -l | grep spring
jstat -gc <pid> 1000  # Every 1 second

# Check database
psql -U privileged_user -d privileged_messaging \
  -c "SELECT COUNT(*) FROM messages;"
```

- [ ] All 100 messages created
- [ ] No database errors
- [ ] No memory leaks
- [ ] No lost push notifications

### Polling Request Reduction

Count requests during 1-minute period:

**Without push:**
```
grep "GET.*messages" /var/log/spring-boot.log | wc -l
# Should be ~6 requests/minute
```

**With push:**
```
grep "GET.*messages" /var/log/spring-boot.log | wc -l
# Should be ~2 requests/minute
```

- [ ] 60-70% reduction in polling requests
- [ ] All messages still delivered

## Phase 11: Security Testing

### Verify No Message Content in Push

1. Monitor APNs traffic (packet sniffing or logs)
2. Send message "SECRET_DATA_12345"
3. Intercept push notification payload

Expected payload:
```json
{
  "aps": {
    "content-available": 1
  },
  "c": "a1b2c3d4e5f6..."
}
```

- [ ] No plaintext message content
- [ ] No ciphertext visible
- [ ] Only hashed conversation ID

### Verify Token Hashing

1. Calculate hash manually:
   - conversationId = "550e8400-e29b-41d4-a716-446655440000"
   - SHA256(uuid_string) = `550e8400e29b41d4a716446655440000`
   - First 32 chars = `550e8400e29b41d4a716446655440000`

2. Check push notification payload
3. Compare hashes

- [ ] Hashes match
- [ ] Full conversation ID not exposed
- [ ] Only first 32 characters sent

### Verify Device ID Not Sent to Apple

Check all outgoing requests to APNs:

```bash
# Monitor network traffic
sudo tcpdump -i any -A "dst api.push.apple.com" | grep -i "device"
```

- [ ] No device identifiers in APNs payload
- [ ] Only token, conversation hash, content-available flag

## Phase 12: Documentation Verification

- [ ] HYBRID_PUSH_IMPLEMENTATION.md is complete and accurate
- [ ] APNs_SETUP_GUIDE.md has all steps
- [ ] IMPLEMENTATION_SUMMARY.md is current
- [ ] Code is properly commented
- [ ] All functions have docstrings
- [ ] Error messages are helpful

## Final Checklist

### Before Production Deployment

- [ ] All phases 1-12 tests passed
- [ ] No errors in logs (only DEBUG and INFO)
- [ ] APNs certificate tested and valid
- [ ] Database migrations run successfully
- [ ] Backend builds without errors
- [ ] iOS app builds without warnings
- [ ] Push notifications arrive reliably
- [ ] Message latency < 1 second average
- [ ] Polling reduces by >60% with push
- [ ] All security checks passed
- [ ] Load test completed successfully
- [ ] Monitoring/logging configured
- [ ] Team trained on troubleshooting
- [ ] Rollback plan documented

### Post-Deployment Monitoring

- [ ] Monitor push delivery rate (goal: >98%)
- [ ] Track message latency distribution
- [ ] Watch for APNs connection errors
- [ ] Alert on unusual token patterns
- [ ] Monitor database query performance
- [ ] Check battery impact on users
- [ ] Review user feedback on responsiveness

## Issues Found & Resolutions

Document any issues encountered during testing:

| Issue | Severity | Root Cause | Resolution | Date |
|-------|----------|-----------|-----------|------|
| | | | | |

---

**Testing Completion Date:** _______________

**Tested By:** _______________

**Approved For Production:** _______________

**Notes:**

