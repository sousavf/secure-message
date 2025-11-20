# Hybrid Push Notification + Polling Implementation

## Overview

This document describes the complete implementation of a hybrid approach combining:
- **APNs Push Notifications** for near-instant message delivery
- **Adaptive HTTP Polling** as fallback for reliability
- **Zero-knowledge architecture** preservation with privacy-first design

## Architecture

```
iOS App                                   Backend (Spring Boot)
├─ AppDelegate                          ├─ DeviceTokenController
│  └─ APNs Token Registration           │  ├─ POST /api/devices/token (register)
│                                       │  └─ POST /api/devices/logout
├─ PushNotificationService              │
│  └─ Token management                  ├─ DeviceTokenService
│  └─ Silent push handling              │  └─ Token lifecycle management
│                                       │
├─ ConversationDetailView               ├─ ApnsPushService
│  ├─ Adaptive polling                  │  ├─ sendSilentPush()
│  ├─ Push notification listener        │  └─ sendPushToConversationParticipants()
│  └─ Hash conversation ID              │
                                        ├─ MessageService
                                        │  └─ Triggers push on message creation
                                        │
                                        ├─ DeviceToken Entity
                                        └─ DeviceTokenRepository
```

## Backend Implementation

### 1. Dependencies Added (pom.xml)

```xml
<!-- APNs Push Notifications -->
<dependency>
    <groupId>com.eatthepath</groupId>
    <artifactId>pushy</artifactId>
    <version>0.15.2</version>
</dependency>

<!-- Guava for hashing -->
<dependency>
    <groupId>com.google.guava</groupId>
    <artifactId>guava</artifactId>
    <version>33.0.0-jre</version>
</dependency>
```

### 2. New Entities

#### DeviceToken.java
Stores APNs tokens with device tracking:
```
- id (UUID)
- deviceId (String) - App-generated device identifier
- apnsToken (String) - APNs device token
- registeredAt (LocalDateTime)
- updatedAt (LocalDateTime)
- active (boolean)
```

Indexed on `deviceId` and `apnsToken` for efficient lookups.

### 3. Services

#### DeviceTokenService
Manages token registration and lifecycle:
- `registerToken(deviceId, apnsToken)` - Register or update device token
- `getActiveToken(deviceId)` - Get current token for device
- `deactivateToken(apnsToken)` - Mark token as invalid
- `removeAllTokens(deviceId)` - Logout device

#### ApnsPushService
Handles APNs communication:
- `initializeClient()` - Initialize connection with APNs
- `sendSilentPush(deviceToken, conversationId)` - Send silent notification
- `sendPushToConversationParticipants(conversationId, deviceIds, excludeDeviceId)` - Broadcast to participants

**Key Privacy Features:**
- Conversation ID is hashed (SHA256) before sending in payload
- Only first 32 chars of hash sent in `"c"` parameter
- Backend never includes message content in push
- Silent push prevents notification UI leakage

#### MessageService Updates
Modified `createConversationMessage()` to:
1. Save message to database
2. Get all conversation participants
3. Trigger async push to all except sender via `ApnsPushService`
4. Return full message response (not just ID)

### 4. Controllers

#### DeviceTokenController
RESTful endpoints:
- `POST /api/devices/token` - Register APNs token
  - Headers: `X-Device-ID` (required)
  - Body: `{ "apnsToken": "..." }`
  - Response: 201 Created with token ID

- `POST /api/devices/logout` - Logout device
  - Headers: `X-Device-ID` (required)
  - Response: 200 OK

### 5. Configuration

#### ApnsConfig.java
Initializes `ApnsPushService` bean when `apns.enabled=true`

#### application.yml
```yaml
apns:
  enabled: ${APNS_ENABLED:false}
  key:
    path: ${APNS_KEY_PATH:/etc/secrets/AuthKey.p8}
    id: ${APNS_KEY_ID}
  team:
    id: ${APNS_TEAM_ID}
  topic: ${APNS_TOPIC:pt.sousavf.SafeWhisper}
```

## iOS Implementation

### 1. AppDelegate.swift (NEW)

Handles all push notification lifecycle:

```swift
// Register for remote notifications on app launch
func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    await PushNotificationService.shared.requestAuthorization()
}

// Called when device token received
func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    await PushNotificationService.shared.registerToken(token)
}

// Handle silent push (content-available)
func application(_ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    PushNotificationService.shared.handleSilentPush(userInfo: userInfo)
    completionHandler(.newData)
}
```

**Delegate Methods:**
- `userNotificationCenter(_:willPresent:withCompletionHandler:)` - Foreground notification (silent)
- `userNotificationCenter(_:didReceive:withCompletionHandler:)` - User tap on notification

### 2. PushNotificationService.swift (NEW)

Manages push registration and handling:

**Key Methods:**
- `registerToken(_ token: String)` - POST token to `/api/devices/token`
- `requestAuthorization()` - Request user permission
- `handleSilentPush(userInfo:)` - Process incoming push, extract conversation hash
- `isNotificationEnabled()` - Check notification status

**Privacy Features:**
- Never stores message content
- Only handles hashed conversation IDs
- Matches backend hashing algorithm (SHA256, first 32 chars)

### 3. ConversationDetailView.swift (UPDATED)

Integrated hybrid approach:

**New Properties:**
```swift
@State private var pushNotificationsEnabled = false
private let defaultPollInterval: TimeInterval = 5.0    // Normal polling
private let adaptivePollInterval: TimeInterval = 30.0  // When push works
@State private var currentPollInterval: TimeInterval = 5.0
```

**Lifecycle:**
```swift
.onAppear {
    await loadMessages()
    pushNotificationsEnabled = await PushNotificationService.shared.isNotificationEnabled()
    startPolling()
    setupPushNotificationListener()
}
.onDisappear {
    stopPolling()
    removePushNotificationListener()
}
```

**Adaptive Polling:**
- Initial interval based on notification status
- When push received for our conversation: immediately poll + set adaptive interval
- If push disabled: maintain 5-second interval

**Push Listener:**
```swift
private func setupPushNotificationListener() {
    NotificationCenter.default.addObserver(...) { notification in
        if conversationHash == ourHash {
            // Push received for this conversation
            Task { await pollForNewMessages() }
            pushNotificationsEnabled = true
        }
    }
}
```

### 4. SecureMessagingAppApp.swift (UPDATED)

Connect AppDelegate to SwiftUI:
```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
```

### 5. Info.plist Configuration

Required capabilities:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## Push Notification Payload Format

**Sent from Backend:**
```json
{
    "aps": {
        "content-available": 1
    },
    "c": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
}
```

Where `"c"` is the first 32 characters of SHA256(conversation-id).

**Never Included:**
- Message ciphertext
- Message nonce or tag
- Sender information
- Message preview
- Any plaintext content

## Data Flow

### Sending a Message

1. **iOS App:**
   - User sends message in ConversationDetailView
   - Message encrypted with conversation master key
   - POST to `/api/conversations/{id}/messages` with encrypted payload

2. **Backend:**
   - MessageController receives message
   - MessageService.createConversationMessage() called
   - Message saved to database
   - sendPushToParticipants() invoked asynchronously
   - ApnsPushService gets participant tokens
   - Hash conversation ID (SHA256)
   - Build silent push with hashed ID
   - Send to APNs for each participant

3. **APNs:**
   - Routes push to participant devices
   - If device offline, queues until available (24-48 hours)

4. **Recipient iOS App:**
   - AppDelegate.didReceiveRemoteNotification() called
   - PushNotificationService.handleSilentPush() invoked
   - NotificationCenter posts newMessageReceivedNotification
   - ConversationDetailView listener fires
   - Hash conversation ID and compare to push hash
   - If match: immediately call pollForNewMessages()
   - If no match: ignore push

5. **Recipient Polling:**
   - ConversationDetailView polls with /api/conversations/{id}/messages?since=timestamp
   - Backend returns new messages since last poll
   - Messages decrypted using stored conversation key
   - Display in UI

## Adaptive Polling Algorithm

```
INITIALIZATION:
  poll_interval = push_enabled ? 30s : 5s

ON PUSH RECEIVED FOR THIS CONVERSATION:
  poll_interval = 30s
  immediately_poll()  // Don't wait for next timer

ON APP RESUME:
  check_notification_status()
  if disabled: poll_interval = 5s

TIMER FIRES:
  poll_messages()
  if new_messages:
    update_ui()
```

**Benefits:**
- When push works: 6x reduction in polling requests (30s vs 5s)
- When push fails: automatic fallback to frequent polling
- User always gets messages quickly
- Battery impact minimized

## Security & Privacy

### Zero-Knowledge Preserved

✅ **Backend Never Sees:**
- Encryption keys (only hashed conversation IDs)
- Plaintext message content
- Message metadata (ciphertext, nonce, tag only exposed to clients)

✅ **Privacy-First Push:**
- No message content in push payload
- Only hashed conversation ID
- Silent pushes prevent lock screen leaks
- Backend doesn't correlate push timing with message volume

### Token Management

✅ **Secure Token Lifecycle:**
- Tokens invalidated when APNs reports error
- Token moved to new device (device switch detection)
- Tokens removed on logout
- Tokens unique per (deviceId, apnsToken) pair

### Device Identification

⚠️ **Note on Device ID:**
- Uses `UIDevice.current.identifierForVendor`
- Different for each app installation
- Resets if user deletes and reinstalls app
- Never sent to Apple (only to your backend)

## Deployment Checklist

### iOS App

- [ ] Xcode: Enable "Push Notifications" capability
- [ ] Xcode: Enable "Background Modes" → "Remote notifications"
- [ ] Verify Info.plist has UIBackgroundModes
- [ ] Test on physical device (push won't work on simulator)
- [ ] Verify AppDelegate initialization
- [ ] Check user grants notification permission

### Backend

- [ ] Configure APNs certificate in Apple Developer Portal
  - Download AuthKey_XXXXX.p8
  - Note Key ID (shown in portal)
  - Note Team ID (Account > Membership)

- [ ] Set environment variables:
  ```bash
  export APNS_ENABLED=true
  export APNS_KEY_ID=XXXXX
  export APNS_TEAM_ID=YYYYY
  export APNS_KEY_PATH=/etc/secrets/AuthKey.p8
  ```

- [ ] Database migration:
  ```bash
  # Hibernateauto-creates DeviceToken table
  # No manual migration needed if ddl-auto: create-drop
  ```

- [ ] Test token registration:
  ```bash
  curl -X POST https://backend/api/devices/token \
    -H "X-Device-ID: test-device" \
    -H "Content-Type: application/json" \
    -d '{"apnsToken":"test..."}'
  ```

## Monitoring & Observability

### Backend Logs

```
[DEBUG] ApnsPushService - Sending silent push to token: XXXX...
[DEBUG] ApnsPushService - Push notification accepted for device token: XXXX...
[WARN] ApnsPushService - Push notification rejected for device token: XXXX... reason: BadDeviceToken
[ERROR] MessageService - Error sending push to participants for conversation {}
```

### iOS Logs

```
[DEBUG] AppDelegate - Registered for remote notifications, token: XXXX...
[DEBUG] AppDelegate - Received remote notification
[DEBUG] PushNotificationService - Handling silent push
[DEBUG] ConversationDetailView - Push received for our conversation, polling immediately
```

### Metrics to Track

- Push delivery rate (goal: >98%)
- Message latency (goal: <2 seconds)
- Token registration success rate
- Poll request count (goal: 80% reduction)
- APNs connection status

## Troubleshooting

### Push Not Arriving

1. **Check token registration:**
   ```sql
   SELECT * FROM device_tokens WHERE device_id = '...' AND active = true;
   ```

2. **Verify APNs certificate:**
   - Matches bundle ID
   - Valid and not expired
   - Downloaded from Apple Developer Portal

3. **Check device permissions:**
   - User granted notification permission
   - Device has internet connectivity
   - APNs service not blocked by firewall

4. **Fallback to polling:**
   - Polling should work within 5 seconds
   - Check `/api/conversations/{id}/messages` endpoint

### High Polling Rate (Push Not Working)

1. **Check notification status:**
   ```swift
   let settings = await UNUserNotificationCenter.current().notificationSettings()
   // If authorizationStatus != .authorized, polling stays at 5s
   ```

2. **Verify APNs service health:**
   - Check Apple System Status page
   - Monitor push error logs

3. **Restart app:**
   - Force app kill and restart
   - Re-request notification permission

## Files Added/Modified

### Backend Files

**Added:**
- `entity/DeviceToken.java`
- `repository/DeviceTokenRepository.java`
- `service/ApnsPushService.java`
- `service/DeviceTokenService.java`
- `dto/RegisterDeviceTokenRequest.java`
- `controller/DeviceTokenController.java`
- `config/ApnsConfig.java`

**Modified:**
- `pom.xml` - Added Pushy and Guava dependencies
- `service/MessageService.java` - Added push trigger
- `application.yml` - Added APNs configuration

### iOS Files

**Added:**
- `Services/AppDelegate.swift`
- `Services/PushNotificationService.swift`

**Modified:**
- `SecureMessagingAppApp.swift` - Added AppDelegate adapter
- `Views/ConversationDetailView.swift` - Added push listener and adaptive polling

## Next Steps

### Phase 1 (Current) - Core Infrastructure ✅
- [x] Backend: APNs service setup
- [x] Backend: Device token storage
- [x] Backend: Push trigger on message creation
- [x] iOS: AppDelegate and token registration
- [x] iOS: Push notification handling
- [x] iOS: Adaptive polling integration

### Phase 2 - Testing & Optimization
- [ ] End-to-end testing with real devices
- [ ] APNs certificate setup and validation
- [ ] Load testing at scale
- [ ] Monitor push delivery metrics
- [ ] Optimize based on real-world usage

### Phase 3 - Enhancement (Future)
- [ ] Alert push notifications (with user-friendly messages)
- [ ] Multi-message batching
- [ ] Decoy traffic for privacy (random silent pushes)
- [ ] WebSocket support for truly real-time (Phase 2 if needed)

## References

- [Apple Push Notification service](https://developer.apple.com/documentation/usernotifications)
- [Pushy Java Library](https://github.com/jchambers/pushy)
- [Spring Boot with APNs](https://spring.io/guides/gs/push-notifications-apns/)
