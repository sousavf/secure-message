# Message Delivery System Design with Status Indicators

## Overview
Implement WhatsApp-style message delivery tracking with Redis buffering for resilient, async message processing.

## Message Lifecycle

### Phase 1: Local Storage (Instant)
```
┌─────────────────────────────────────────────────────────┐
│ USER SENDS MESSAGE                                      │
└─────────────────────────────────────────────────────────┘
                    │
                    │ 1. Save to local Core Data (< 50ms)
                    ▼
         ┌──────────────────────┐
         │   Local Database     │
         │  Status: QUEUED ⏰   │
         │  syncStatus: pending │
         │  sentAt: null        │
         │  deliveredAt: null   │
         └──────────────────────┘
                    │
                    │ 2. Display in UI immediately
                    ▼
         ┌──────────────────────┐
         │   Message Bubble     │
         │   [Message text]     │
         │   12:34 PM ⏰        │  ← Clock icon (queued)
         └──────────────────────┘
```

### Phase 2: Send to Redis (Async)
```
         ┌──────────────────────┐
         │   Background Task    │
         │   Checks if online   │
         └──────────────────────┘
                    │
                    │ 3. POST to /api/messages/send-buffered
                    ▼
         ┌──────────────────────┐
         │   Backend: Redis     │
         │   Store in queue     │
         │   Return ACK         │
         └──────────────────────┘
                    │
                    │ 4. Update local DB
                    ▼
         ┌──────────────────────┐
         │   Local Database     │
         │  Status: SENT ✓      │
         │  syncStatus: sent    │
         │  sentAt: now()       │
         │  serverId: uuid      │
         └──────────────────────┘
                    │
                    │ 5. Update UI
                    ▼
         ┌──────────────────────┐
         │   Message Bubble     │
         │   [Message text]     │
         │   12:34 PM ✓         │  ← Single check (sent)
         └──────────────────────┘
```

### Phase 3: Redis → Database (Backend Async)
```
         ┌──────────────────────┐
         │   Redis Consumer     │
         │   (Backend worker)   │
         └──────────────────────┘
                    │
                    │ 6. Pop from Redis queue
                    │ 7. Validate & encrypt
                    ▼
         ┌──────────────────────┐
         │  PostgreSQL Database │
         │  Message stored      │
         │  ID: server_uuid     │
         └──────────────────────┘
                    │
                    │ 8. Publish WebSocket event
                    │    "message_delivered"
                    ▼
         ┌──────────────────────┐
         │   iOS App (via WS)   │
         │   Update local DB    │
         └──────────────────────┘
                    │
                    │ 9. Update status
                    ▼
         ┌──────────────────────┐
         │   Local Database     │
         │  Status: DELIVERED ✓✓│
         │  syncStatus: synced  │
         │  deliveredAt: now()  │
         └──────────────────────┘
                    │
                    │ 10. Update UI
                    ▼
         ┌──────────────────────┐
         │   Message Bubble     │
         │   [Message text]     │
         │   12:34 PM ✓✓        │  ← Double check (delivered)
         └──────────────────────┘
```

### Phase 4: Read by Recipient
```
         ┌──────────────────────┐
         │  Recipient opens msg │
         │  Backend sets readAt │
         └──────────────────────┘
                    │
                    │ 11. WebSocket notification
                    ▼
         ┌──────────────────────┐
         │   iOS App (sender)   │
         │   Update read status │
         └──────────────────────┘
                    │
                    │ 12. Update UI
                    ▼
         ┌──────────────────────┐
         │   Message Bubble     │
         │   [Message text]     │
         │   12:34 PM ✓✓        │  ← Blue double check (read)
         └──────────────────────┘
```

## Backend Architecture Changes

### New Redis Queue System

#### 1. Message Buffer Endpoint
```java
// New endpoint: POST /api/conversations/{id}/messages/buffered
@PostMapping("/conversations/{conversationId}/messages/buffered")
public ResponseEntity<?> sendMessageBuffered(
        @PathVariable UUID conversationId,
        @RequestHeader("X-Device-ID") String deviceId,
        @RequestBody CreateMessageRequest request) {
    try {
        // Generate server ID immediately
        UUID serverId = UUID.randomUUID();

        // Store in Redis queue (fast, < 10ms)
        BufferedMessage buffered = new BufferedMessage(
            serverId,
            conversationId,
            deviceId,
            request.getCiphertext(),
            request.getNonce(),
            request.getTag(),
            request.getMessageType(),
            Instant.now()
        );

        redisTemplate.opsForList()
            .rightPush("message_queue", buffered);

        // Return immediately with server ID
        return ResponseEntity.status(HttpStatus.ACCEPTED)
            .body(new MessageBufferedResponse(serverId, "QUEUED_FOR_PROCESSING"));

    } catch (Exception e) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
            .body(new ErrorResponse("Failed to queue message"));
    }
}

class MessageBufferedResponse {
    UUID serverId;           // Server-assigned message ID
    String status;           // "QUEUED_FOR_PROCESSING"
    Instant queuedAt;        // When it entered Redis
}
```

#### 2. Async Message Processor
```java
// New service: MessageQueueProcessor.java
@Service
public class MessageQueueProcessor {

    @Scheduled(fixedDelay = 100) // Process every 100ms
    public void processMessageQueue() {
        while (true) {
            // Pop from Redis queue
            BufferedMessage buffered = redisTemplate.opsForList()
                .leftPop("message_queue");

            if (buffered == null) break; // Queue empty

            try {
                // Process message (validate, save to DB)
                Message message = processBufferedMessage(buffered);

                // Save to PostgreSQL
                messageRepository.save(message);

                // Notify sender via WebSocket
                webSocketService.notifyMessageDelivered(
                    buffered.deviceId,
                    buffered.serverId
                );

                // Notify recipient(s) new message available
                webSocketService.notifyNewMessage(
                    buffered.conversationId,
                    message.getId()
                );

                logger.info("Message processed: {} -> {}",
                    buffered.serverId, message.getId());

            } catch (Exception e) {
                // Retry logic
                handleFailedMessage(buffered, e);
            }
        }
    }

    private void handleFailedMessage(BufferedMessage msg, Exception e) {
        msg.retryCount++;

        if (msg.retryCount < 3) {
            // Push back to queue for retry
            redisTemplate.opsForList()
                .rightPush("message_queue", msg);
        } else {
            // Dead letter queue
            redisTemplate.opsForList()
                .rightPush("message_queue_failed", msg);

            // Notify sender of failure
            webSocketService.notifyMessageFailed(
                msg.deviceId,
                msg.serverId
            );
        }
    }
}
```

#### 3. WebSocket Notifications
```java
// WebSocketService.java
@Service
public class WebSocketService {

    // Notify sender: message delivered to database
    public void notifyMessageDelivered(String deviceId, UUID serverId) {
        WebSocketMessage notification = new WebSocketMessage(
            "MESSAGE_DELIVERED",
            Map.of(
                "serverId", serverId,
                "deliveredAt", Instant.now(),
                "status", "DELIVERED"
            )
        );

        messagingTemplate.convertAndSendToUser(
            deviceId,
            "/queue/notifications",
            notification
        );
    }

    // Notify sender: message failed to process
    public void notifyMessageFailed(String deviceId, UUID serverId) {
        WebSocketMessage notification = new WebSocketMessage(
            "MESSAGE_FAILED",
            Map.of(
                "serverId", serverId,
                "failedAt", Instant.now(),
                "status", "FAILED"
            )
        );

        messagingTemplate.convertAndSendToUser(
            deviceId,
            "/queue/notifications",
            notification
        );
    }

    // Notify recipient: new message available
    public void notifyNewMessage(UUID conversationId, UUID messageId) {
        List<String> participants = conversationService
            .getActiveParticipants(conversationId)
            .stream()
            .map(p -> p.getDeviceId())
            .toList();

        for (String participant : participants) {
            WebSocketMessage notification = new WebSocketMessage(
                "NEW_MESSAGE",
                Map.of(
                    "conversationId", conversationId,
                    "messageId", messageId
                )
            );

            messagingTemplate.convertAndSendToUser(
                participant,
                "/queue/notifications",
                notification
            );
        }
    }
}
```

## iOS Implementation

### Enhanced Message Model
```swift
// Models.swift - Add delivery status
struct ConversationMessage: Identifiable, Codable {
    let id: UUID
    var serverId: UUID?              // Server-assigned ID (after buffer)
    let ciphertext: String?
    let nonce: String?
    let tag: String?
    let createdAt: Date?
    let consumed: Bool
    let conversationId: UUID?
    let expiresAt: Date?
    let readAt: Date?
    let senderDeviceId: String?
    var messageType: MessageType?

    // Delivery status fields
    var syncStatus: SyncStatus = .pending
    var sentAt: Date?               // When sent to Redis
    var deliveredAt: Date?          // When processed to DB
    var failedAt: Date?             // If processing failed

    enum SyncStatus: String, Codable {
        case pending    // Local only, not sent
        case sending    // Currently uploading
        case sent       // In Redis queue (✓)
        case delivered  // In database (✓✓)
        case read       // Opened by recipient (✓✓ blue)
        case failed     // Send failed (⚠️)
    }
}
```

### Core Data Entity
```swift
// CachedMessage+CoreDataProperties.swift
@NSManaged public var id: UUID
@NSManaged public var serverId: UUID?
@NSManaged public var syncStatus: String       // "pending", "sent", "delivered", "read", "failed"
@NSManaged public var sentAt: Date?
@NSManaged public var deliveredAt: Date?
@NSManaged public var failedAt: Date?
@NSManaged public var retryCount: Int16
```

### Message Sending Service
```swift
// Services/MessageSendingService.swift
class MessageSendingService {

    // Send message with delivery tracking
    func sendMessage(
        _ message: ConversationMessage,
        to conversationId: UUID
    ) async throws {

        // 1. Save to local DB immediately (PENDING)
        var localMessage = message
        localMessage.syncStatus = .pending
        localMessage.id = UUID() // Local ID

        await CacheService.shared.saveMessage(localMessage, for: conversationId)

        // 2. Return immediately (UI shows clock icon)
        NotificationCenter.default.post(
            name: .messageCreated,
            object: localMessage
        )

        // 3. Send to server in background
        Task.detached(priority: .userInitiated) {
            await self.sendToServer(localMessage, conversationId: conversationId)
        }
    }

    private func sendToServer(
        _ message: ConversationMessage,
        conversationId: UUID
    ) async {

        guard NetworkMonitor.shared.isConnected else {
            // Stay in PENDING, will retry when online
            print("Offline - message queued locally")
            return
        }

        do {
            // Update status to SENDING
            await updateMessageStatus(message.id, status: .sending)

            // Send to buffered endpoint
            let request = CreateMessageRequest(
                ciphertext: message.ciphertext ?? "",
                nonce: message.nonce ?? "",
                tag: message.tag ?? "",
                messageType: message.messageType ?? .text
            )

            let response = try await apiService.sendMessageBuffered(
                conversationId: conversationId,
                request: request,
                deviceId: DeviceID.current
            )

            // Update status to SENT (✓)
            var updatedMessage = message
            updatedMessage.serverId = response.serverId
            updatedMessage.syncStatus = .sent
            updatedMessage.sentAt = Date()

            await CacheService.shared.updateMessage(updatedMessage)

            // Notify UI to update check mark
            NotificationCenter.default.post(
                name: .messageSent,
                object: updatedMessage
            )

            print("Message sent to server: \(response.serverId)")

        } catch {
            // Mark as failed
            await handleSendFailure(message, error: error)
        }
    }

    private func handleSendFailure(
        _ message: ConversationMessage,
        error: Error
    ) async {
        var failedMessage = message
        failedMessage.syncStatus = .failed
        failedMessage.failedAt = Date()
        failedMessage.retryCount += 1

        await CacheService.shared.updateMessage(failedMessage)

        // Retry if network error (not validation error)
        if case NetworkError.serverError = error,
           failedMessage.retryCount < 3 {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            await sendToServer(failedMessage, conversationId: message.conversationId!)
        }
    }
}
```

### WebSocket Handler
```swift
// Services/WebSocketService.swift
class WebSocketService {

    func handleWebSocketMessage(_ notification: WebSocketMessage) {
        switch notification.type {

        case "MESSAGE_DELIVERED":
            // Update status to DELIVERED (✓✓)
            let serverId = notification.data["serverId"] as! UUID

            Task {
                await updateMessageDeliveryStatus(
                    serverId: serverId,
                    status: .delivered,
                    deliveredAt: Date()
                )
            }

        case "MESSAGE_FAILED":
            // Update status to FAILED (⚠️)
            let serverId = notification.data["serverId"] as! UUID

            Task {
                await updateMessageDeliveryStatus(
                    serverId: serverId,
                    status: .failed,
                    failedAt: Date()
                )
            }

        case "MESSAGE_READ":
            // Update status to READ (✓✓ blue)
            let messageId = notification.data["messageId"] as! UUID

            Task {
                await updateMessageReadStatus(
                    messageId: messageId,
                    readAt: Date()
                )
            }

        default:
            break
        }
    }

    private func updateMessageDeliveryStatus(
        serverId: UUID,
        status: ConversationMessage.SyncStatus,
        deliveredAt: Date
    ) async {
        // Find local message by serverId
        if let message = await CacheService.shared.findMessage(byServerId: serverId) {
            var updated = message
            updated.syncStatus = status
            updated.deliveredAt = deliveredAt

            await CacheService.shared.updateMessage(updated)

            // Notify UI
            NotificationCenter.default.post(
                name: .messageDelivered,
                object: updated
            )
        }
    }
}
```

### UI Component - Message Status Indicator
```swift
// Views/MessageStatusView.swift
struct MessageStatusView: View {
    let message: ConversationMessage

    var body: some View {
        HStack(spacing: 2) {
            timeText
            statusIcon
        }
    }

    private var timeText: some View {
        Text(message.createdAt?.formatted(date: .omitted, time: .shortened) ?? "")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.7))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.syncStatus {
        case .pending:
            // Clock icon (queued locally)
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))

        case .sending:
            // Spinner (uploading)
            ProgressView()
                .scaleEffect(0.5)

        case .sent:
            // Single check (in Redis)
            Text("✓")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))

        case .delivered:
            // Double check (in database)
            HStack(spacing: -2) {
                Text("✓")
                Text("✓")
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.8))

        case .read:
            // Double check, blue (opened by recipient)
            HStack(spacing: -2) {
                Text("✓")
                Text("✓")
            }
            .font(.caption2)
            .foregroundColor(.blue)

        case .failed:
            // Warning icon (failed to send)
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                Text("Tap to retry")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
            .onTapGesture {
                retryMessage()
            }
        }
    }

    private func retryMessage() {
        Task {
            await MessageSendingService.shared.sendToServer(
                message,
                conversationId: message.conversationId!
            )
        }
    }
}
```

### Updated ConversationMessageRow
```swift
// Replace timestamp section with status indicator
HStack(spacing: 4) {
    Spacer()

    if isSentByCurrentDevice {
        MessageStatusView(message: message)
    } else {
        // For received messages, just show time
        Text(message.createdAt?.formatted(date: .omitted, time: .shortened) ?? "")
            .font(.caption2)
            .foregroundColor(.gray)
    }
}
.padding(.horizontal, 12)
.padding(.bottom, 4)
```

## Sync Queue Management

### Offline Queue Processor
```swift
// Services/OfflineQueueService.swift
class OfflineQueueService {

    // Process pending messages when coming online
    func processPendingMessages() async {
        let pending = await CacheService.shared.getPendingMessages()

        print("Processing \(pending.count) pending messages")

        for message in pending {
            await MessageSendingService.shared.sendToServer(
                message,
                conversationId: message.conversationId!
            )

            // Small delay to avoid overwhelming server
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }

    // Monitor network status
    func startMonitoring() {
        NetworkMonitor.shared.onConnected = {
            Task {
                await self.processPendingMessages()
            }
        }
    }
}
```

## Performance Considerations

### Redis Configuration
```yaml
# Backend: application.yml
spring:
  redis:
    # Message queue configuration
    timeout: 2000ms
    lettuce:
      pool:
        max-active: 20
        max-idle: 10
        min-idle: 5

# Custom queue settings
app:
  message-queue:
    max-size: 10000          # Max messages in queue
    batch-size: 100          # Process 100 messages per batch
    processing-interval: 100 # Process every 100ms
    retry-attempts: 3        # Retry failed messages 3 times
    dead-letter-ttl: 86400   # Keep failed messages 24h
```

### Metrics to Track
```
- Queue size (current messages in Redis)
- Processing rate (messages/second)
- Average processing time (ms per message)
- Retry rate (% of messages retried)
- Failure rate (% reaching dead letter queue)
- Delivery latency (time from send to delivered)
```

## Benefits of This Approach

### 1. Instant User Feedback
```
User types → Hits send → Message appears immediately ⏰
No spinning loader, no "Sending..." delay
Feels instant even on slow networks
```

### 2. Offline Resilience
```
User offline → Writes message → Saved locally ⏰
Comes online → Auto-sends → ✓ appears
No lost messages, seamless experience
```

### 3. Server Load Balancing
```
1000 users send at once → All go to Redis (fast)
Redis queue → Backend processes at controlled rate
Database never overwhelmed
```

### 4. Retry Logic
```
Send fails → Stays in queue ⏰
Network returns → Auto-retry
3 attempts → Failed state ⚠️ with manual retry
```

### 5. Clear User Communication
```
⏰ = I have your message, will send
✓  = Server received it
✓✓ = Delivered and available for recipient
✓✓ (blue) = Recipient read it
⚠️ = Something went wrong, tap to retry
```

## Migration Strategy

### Phase 1: Backend Redis Integration (Week 1)
- Add Redis queue
- Create buffered endpoint
- Implement async processor
- Add WebSocket notifications

### Phase 2: iOS Local DB + Status (Week 2)
- Add Core Data with syncStatus fields
- Implement message sending service
- Add status indicators to UI
- Test offline queue

### Phase 3: WebSocket Integration (Week 3)
- Connect WebSocket handler
- Update delivery status from notifications
- Test real-time updates

### Phase 4: Polish & Testing (Week 4)
- Add retry UI
- Implement queue monitoring
- Performance testing
- Load testing (1000 concurrent sends)

## Testing Checklist

- [ ] Send message online → See ⏰ → ✓ → ✓✓
- [ ] Send message offline → See ⏰ → Come online → ✓ → ✓✓
- [ ] Kill app while sending → Reopen → Message still queued
- [ ] Send 100 messages rapidly → All process correctly
- [ ] Recipient reads message → Sender sees blue ✓✓
- [ ] Network error during send → See ⚠️ → Tap to retry → ✓
- [ ] Backend restart → Messages in Redis not lost

## Conclusion

This delivery status system provides:
✅ WhatsApp-level user experience
✅ Clear communication of message state
✅ Resilient offline support
✅ Scalable server architecture
✅ Automatic retry logic
✅ Real-time status updates

Combined with the offline cache system, users get instant, reliable messaging with full transparency of delivery status.
