# Offline Cache + Delivery Status Implementation Status

## Overview
This document tracks the implementation of the WhatsApp-style offline cache system with Redis buffering and delivery status indicators.

## Completed Components ✅

### Backend
1. ✅ **Dependencies Added** (`pom.xml`)
   - Spring Boot Data Redis (already present)
   - Spring Boot WebSocket (newly added)
   - Jedis Redis client (already present)

2. ✅ **DTOs Created**
   - `BufferedMessage.java` - Message queued in Redis
   - `MessageBufferedResponse.java` - Response when message queued

3. ✅ **WebSocket Configuration**
   - `WebSocketConfig.java` - STOMP over WebSocket setup
   - Endpoints: `/ws` for connections
   - Destinations: `/topic`, `/queue`, `/user`

### Documentation
1. ✅ **Architecture Documents**
   - `OFFLINE_CACHE_IMPLEMENTATION_PLAN.md`
   - `MESSAGE_DELIVERY_SYSTEM_DESIGN.md`
   - `COMPLETE_OFFLINE_SYSTEM_INTEGRATION.md`

## Implementation Needed 🔧

### Backend (Critical Path - Week 1-2)

#### 1. Redis Message Queue Service
```java
// src/main/java/pt/sousavf/securemessaging/service/MessageQueueService.java

@Service
public class MessageQueueService {

    @Autowired
    private RedisTemplate<String, BufferedMessage> redisTemplate;

    private static final String MESSAGE_QUEUE = "message_queue";

    /**
     * Add message to Redis queue (fast, < 10ms)
     */
    public void queueMessage(BufferedMessage message) {
        redisTemplate.opsForList().rightPush(MESSAGE_QUEUE, message);
        logger.info("Message queued: {}", message.getServerId());
    }

    /**
     * Pop message from queue for processing
     */
    public BufferedMessage popMessage() {
        return redisTemplate.opsForList().leftPop(MESSAGE_QUEUE);
    }

    /**
     * Get current queue size
     */
    public Long getQueueSize() {
        return redisTemplate.opsForList().size(MESSAGE_QUEUE);
    }
}
```

#### 2. Async Message Processor
```java
// src/main/java/pt/sousavf/securemessaging/service/MessageQueueProcessor.java

@Service
public class MessageQueueProcessor {

    @Autowired
    private MessageQueueService queueService;

    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private ConversationService conversationService;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    /**
     * Process messages from Redis queue every 100ms
     */
    @Scheduled(fixedDelay = 100)
    public void processMessageQueue() {
        int processed = 0;

        // Process up to 100 messages per batch
        while (processed < 100) {
            BufferedMessage buffered = queueService.popMessage();
            if (buffered == null) break; // Queue empty

            try {
                // Create message entity
                Message message = new Message();
                message.setCiphertext(buffered.getCiphertext());
                message.setNonce(buffered.getNonce());
                message.setTag(buffered.getTag());
                message.setMessageType(buffered.getMessageType());
                message.setConversationId(buffered.getConversationId());
                message.setSenderDeviceId(buffered.getDeviceId());

                // Set expiration from conversation
                Conversation conv = conversationService.getConversation(
                    buffered.getConversationId()
                ).orElseThrow();
                message.setExpiresAt(conv.getExpiresAt());

                // Save to database
                Message saved = messageRepository.save(message);

                // Notify sender: MESSAGE_DELIVERED
                notifyMessageDelivered(buffered.getDeviceId(), buffered.getServerId(), saved.getId());

                // Notify recipients: NEW_MESSAGE
                notifyNewMessage(buffered.getConversationId(), saved.getId());

                processed++;
                logger.info("Message processed: {} -> {}", buffered.getServerId(), saved.getId());

            } catch (Exception e) {
                logger.error("Failed to process message: {}", buffered.getServerId(), e);
                handleFailedMessage(buffered, e);
            }
        }
    }

    private void handleFailedMessage(BufferedMessage msg, Exception e) {
        msg.setRetryCount(msg.getRetryCount() + 1);

        if (msg.getRetryCount() < 3) {
            // Retry
            queueService.queueMessage(msg);
        } else {
            // Dead letter queue (log or store separately)
            logger.error("Message failed after 3 retries: {}", msg.getServerId());
            notifyMessageFailed(msg.getDeviceId(), msg.getServerId());
        }
    }

    private void notifyMessageDelivered(String deviceId, UUID serverId, UUID messageId) {
        Map<String, Object> payload = Map.of(
            "type", "MESSAGE_DELIVERED",
            "serverId", serverId.toString(),
            "messageId", messageId.toString(),
            "deliveredAt", Instant.now().toString()
        );

        messagingTemplate.convertAndSendToUser(
            deviceId,
            "/queue/notifications",
            payload
        );
    }

    private void notifyNewMessage(UUID conversationId, UUID messageId) {
        Map<String, Object> payload = Map.of(
            "type", "NEW_MESSAGE",
            "conversationId", conversationId.toString(),
            "messageId", messageId.toString()
        );

        messagingTemplate.convertAndSend(
            "/topic/conversation/" + conversationId,
            payload
        );
    }

    private void notifyMessageFailed(String deviceId, UUID serverId) {
        Map<String, Object> payload = Map.of(
            "type", "MESSAGE_FAILED",
            "serverId", serverId.toString(),
            "failedAt", Instant.now().toString()
        );

        messagingTemplate.convertAndSendToUser(
            deviceId,
            "/queue/notifications",
            payload
        );
    }
}
```

#### 3. Buffered Message Endpoint
```java
// Add to MessageController.java

/**
 * Send message to Redis queue for async processing
 * Returns immediately with server-assigned ID
 */
@PostMapping("/conversations/{conversationId}/messages/buffered")
public ResponseEntity<?> sendMessageBuffered(
        @PathVariable UUID conversationId,
        @RequestHeader("X-Device-ID") String deviceId,
        @RequestBody CreateMessageRequest request) {
    try {
        // Generate server ID immediately
        UUID serverId = UUID.randomUUID();

        // Create buffered message
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

        // Queue in Redis (fast, < 10ms)
        messageQueueService.queueMessage(buffered);

        // Return immediately
        MessageBufferedResponse response = new MessageBufferedResponse(
            serverId,
            "QUEUED_FOR_PROCESSING",
            buffered.getQueuedAt()
        );

        return ResponseEntity.status(HttpStatus.ACCEPTED).body(response);

    } catch (Exception e) {
        logger.error("Failed to queue message", e);
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
            .body(new ErrorResponse("Failed to queue message: " + e.getMessage()));
    }
}
```

### iOS (Critical Path - Week 2-4)

#### 1. Core Data Model
Create `SecureMessaging.xcdatamodeld` in Xcode with entities:

**CachedConversation:**
- id: UUID
- initiatorUserId: UUID (optional)
- status: String
- createdAt: Date
- expiresAt: Date
- encryptionKey: String (encrypted)
- localName: String (optional)
- lastSyncedAt: Date (optional)

**CachedMessage:**
- id: UUID
- serverId: UUID (optional)
- conversationId: UUID
- ciphertext: String
- nonce: String
- tag: String
- messageType: String
- syncStatus: String (pending/sent/delivered/read/failed)
- sentAt: Date (optional)
- deliveredAt: Date (optional)
- readAt: Date (optional)
- senderDeviceId: String
- createdAt: Date
- expiresAt: Date
- consumed: Bool
- fileName: String (optional)
- fileSize: Int32
- fileMimeType: String (optional)
- fileUrl: String (optional)

#### 2. Persistence Controller
```swift
// Services/PersistenceController.swift

import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SecureMessaging")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving Core Data: \(error)")
            }
        }
    }
}
```

#### 3. Cache Service
```swift
// Services/CacheService.swift

import CoreData
import Foundation

class CacheService {
    static let shared = CacheService()
    private let persistence = PersistenceController.shared

    // MARK: - Conversations

    func saveConversations(_ conversations: [Conversation]) {
        let context = persistence.container.viewContext

        for convo in conversations {
            let cached = CachedConversation(context: context)
            cached.id = convo.id
            cached.initiatorUserId = convo.initiatorUserId
            cached.status = convo.status
            cached.createdAt = convo.createdAt
            cached.expiresAt = convo.expiresAt
            cached.encryptionKey = convo.encryptionKey
            cached.localName = convo.localName
            cached.lastSyncedAt = Date()
        }

        persistence.save()
    }

    func getConversations() -> [Conversation] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedConversation> = CachedConversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let cached = try context.fetch(request)
            return cached.map { $0.toConversation() }
        } catch {
            print("Error fetching conversations: \(error)")
            return []
        }
    }

    // MARK: - Messages

    func saveMessage(_ message: ConversationMessage, for conversationId: UUID) {
        let context = persistence.container.viewContext

        let cached = CachedMessage(context: context)
        cached.id = message.id
        cached.serverId = message.serverId
        cached.conversationId = conversationId
        cached.ciphertext = message.ciphertext
        cached.nonce = message.nonce
        cached.tag = message.tag
        cached.messageType = message.messageType?.rawValue
        cached.syncStatus = message.syncStatus.rawValue
        cached.sentAt = message.sentAt
        cached.deliveredAt = message.deliveredAt
        cached.readAt = message.readAt
        cached.senderDeviceId = message.senderDeviceId
        cached.createdAt = message.createdAt
        cached.expiresAt = message.expiresAt
        cached.consumed = message.consumed

        persistence.save()
    }

    func getMessages(for conversationId: UUID) -> [ConversationMessage] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "conversationId == %@", conversationId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            let cached = try context.fetch(request)
            return cached.map { $0.toMessage() }
        } catch {
            print("Error fetching messages: \(error)")
            return []
        }
    }

    func updateMessageStatus(_ id: UUID, status: ConversationMessage.SyncStatus) {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let cached = try context.fetch(request).first {
                cached.syncStatus = status.rawValue
                if status == .sent {
                    cached.sentAt = Date()
                } else if status == .delivered {
                    cached.deliveredAt = Date()
                }
                persistence.save()
            }
        } catch {
            print("Error updating message status: \(error)")
        }
    }

    func getPendingMessages() -> [ConversationMessage] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "syncStatus == %@", ConversationMessage.SyncStatus.pending.rawValue)

        do {
            let cached = try context.fetch(request)
            return cached.map { $0.toMessage() }
        } catch {
            print("Error fetching pending messages: \(error)")
            return []
        }
    }
}
```

## Next Steps

### Immediate (This Week)
1. Create `MessageQueueService.java` - Redis queue operations
2. Create `MessageQueueProcessor.java` - Async processor
3. Add buffered endpoint to `MessageController.java`
4. Test backend with Postman/curl

### Week 2
1. Create Core Data model in Xcode
2. Implement `PersistenceController.swift`
3. Implement `CacheService.swift`
4. Update `Models.swift` with `SyncStatus` enum

### Week 3
1. Implement `MessageSendingService.swift`
2. Update UI with status indicators (⏰ ✓ ✓✓)
3. Implement `WebSocketService.swift`
4. Test offline functionality

### Week 4
1. Implement `OfflineQueueService.swift`
2. Implement `NetworkMonitor.swift`
3. Add auto-retry logic
4. Full integration testing

### Week 5-6
1. Performance optimization
2. Security audit (Keychain migration)
3. Load testing
4. User acceptance testing

## Testing Checklist

- [ ] Send message online → See ⏰ → ✓ → ✓✓
- [ ] Send message offline → ⏰ → Connect → ✓ → ✓✓
- [ ] Kill app while sending → Reopen → Sends automatically
- [ ] Backend restart → Redis queue persists
- [ ] 1000 concurrent sends → All process correctly
- [ ] Recipient reads → Sender sees blue ✓✓

## Resources

- Full architecture: See `COMPLETE_OFFLINE_SYSTEM_INTEGRATION.md`
- Message delivery: See `MESSAGE_DELIVERY_SYSTEM_DESIGN.md`
- Offline cache: See `OFFLINE_CACHE_IMPLEMENTATION_PLAN.md`

## Contact

For questions or clarifications on this implementation, refer to the detailed architecture documents created.
