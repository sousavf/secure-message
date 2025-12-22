# Offline Cache Implementation Plan for Safe Whisper

## Overview
Implement WhatsApp-like offline functionality where users can view conversations and messages without network connection.

## Current State
- ❌ No persistent message storage
- ❌ No offline access
- ❌ All data lost on app restart
- ⚠️ Encryption keys in UserDefaults (not Keychain)

## Target State
- ✅ All conversations cached locally
- ✅ All messages cached locally (encrypted)
- ✅ Downloaded files cached (encrypted)
- ✅ Instant load from cache
- ✅ Background sync when online
- ✅ Secure storage using Keychain

## Architecture

### Data Flow
```
Online Mode:
User opens app → Load from cache (instant) → Sync in background → Update cache

Offline Mode:
User opens app → Load from cache (instant) → Show "offline" indicator

Sending Messages:
Online:  Save to cache → Send to server → Mark synced
Offline: Save to cache → Queue for sync → Send when online
```

### Storage Layers

#### Layer 1: Core Data (Structure)
- Stores conversation/message structure
- NOT encrypted by default
- Fast queries and relationships

#### Layer 2: Encryption (Security)
- Encrypt sensitive fields before saving
- Use iOS Keychain for encryption keys
- Decrypt only when displaying

#### Layer 3: Sync Engine (Consistency)
- Track last sync time per conversation
- Incremental sync (only fetch new messages)
- Conflict resolution (server wins)

## Implementation Steps

### Phase 1: Foundation (Week 1)

**Step 1.1: Create Core Data Model**
```
File: SecureMessaging.xcdatamodeld

Entities:
- CachedConversation
- CachedMessage
- CachedFile
- SyncMetadata
```

**Step 1.2: Create PersistenceController**
```swift
// PersistenceController.swift
class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "SecureMessaging")
        container.loadPersistentStores()
    }
}
```

**Step 1.3: Migrate KeyStore to Keychain**
```swift
// Migrate encryption keys from UserDefaults → Keychain
// More secure, encrypted by iOS
```

### Phase 2: Cache Service (Week 1-2)

**Step 2.1: Create CacheService**
```swift
// Services/CacheService.swift
class CacheService {
    // Conversations
    func saveConversations(_ conversations: [Conversation])
    func getConversations() -> [Conversation]
    func deleteConversation(_ id: UUID)

    // Messages
    func saveMessages(_ messages: [ConversationMessage], for conversationId: UUID)
    func getMessages(for conversationId: UUID) -> [ConversationMessage]
    func deleteMessage(_ id: UUID)

    // Sync metadata
    func updateLastSync(_ date: Date, for conversationId: UUID)
    func getLastSync(for conversationId: UUID) -> Date?

    // Cleanup
    func deleteExpiredData()
    func enforceCacheLimit(maxSizeMB: Int)
}
```

**Step 2.2: Add Encryption Wrapper**
```swift
// Services/SecureCache.swift
class SecureCache {
    private let key: SymmetricKey // From Keychain

    func encrypt(_ data: Data) -> Data
    func decrypt(_ data: Data) -> Data

    func encryptString(_ string: String) -> String
    func decryptString(_ encrypted: String) -> String
}
```

### Phase 3: Sync Engine (Week 2)

**Step 3.1: Create SyncService**
```swift
// Services/SyncService.swift
class SyncService {
    func syncConversations() async
    func syncMessages(for conversationId: UUID) async
    func syncPendingMessages() async // Send queued messages

    // Background sync
    func enableBackgroundSync()
    func performBackgroundSync()
}
```

**Step 3.2: Modify APIService**
```swift
// Update APIService to work with cache
extension APIService {
    func loadConversations(cacheFirst: Bool = true) async -> [Conversation] {
        if cacheFirst {
            if let cached = CacheService.shared.getConversations() {
                Task { await syncConversationsInBackground() }
                return cached
            }
        }
        return try await fetchConversations()
    }
}
```

### Phase 4: UI Updates (Week 2-3)

**Step 4.1: Update ConversationListView**
```swift
// Load from cache immediately
.onAppear {
    conversations = CacheService.shared.getConversations()
    Task { await syncConversations() }
}
```

**Step 4.2: Update ConversationDetailView**
```swift
// Load messages from cache
.onAppear {
    messages = CacheService.shared.getMessages(for: conversation.id)
    Task { await syncMessages() }
}
```

**Step 4.3: Add Offline Indicator**
```swift
// Show banner when offline
if !NetworkMonitor.shared.isConnected {
    Text("Offline - showing cached messages")
        .foregroundColor(.orange)
}
```

### Phase 5: File Caching (Week 3)

**Step 5.1: Cache Downloaded Files**
```swift
// After downloading and decrypting file
let cachedFile = CachedFile(context: context)
cachedFile.encryptedData = SecureCache.shared.encrypt(decryptedFileData)
cachedFile.messageId = message.id
cachedFile.downloadedAt = Date()
```

**Step 5.2: Load Files from Cache**
```swift
// Check cache before downloading
if let cached = CacheService.shared.getFile(for: message.id) {
    return cached.decryptedData
}
// Otherwise download
```

### Phase 6: Cleanup & Optimization (Week 3-4)

**Step 6.1: TTL Enforcement**
```swift
// Run on app startup
CacheCleanupService.shared.deleteExpiredData()
```

**Step 6.2: Cache Size Limit**
```swift
// Limit to 500MB, delete oldest first
CacheCleanupService.shared.enforceCacheLimit(maxSizeMB: 500)
```

**Step 6.3: Background Sync**
```swift
// iOS Background App Refresh
func application(_ app: UIApplication, performFetchWithCompletionHandler completion: @escaping (UIBackgroundFetchResult) -> Void) {
    Task {
        await SyncService.shared.performBackgroundSync()
        completion(.newData)
    }
}
```

## Security Considerations

### 1. Encryption at Rest
```
- Decrypted message content: MUST be encrypted before Core Data
- Downloaded files: MUST be encrypted before Core Data
- Encryption key: MUST be in Keychain (NOT UserDefaults)
```

### 2. Secure Deletion
```
- When message expires: Securely wipe from Core Data
- When conversation deleted: Wipe all related messages
- Use NSData.resetBytes(in:) for secure wipe
```

### 3. Keychain Migration
```
Current: UserDefaults (plaintext, accessible to jailbroken devices)
Target:  Keychain (encrypted, hardware-backed on modern devices)
```

### 4. Cache Encryption Key
```
Generate master cache encryption key
Store in Keychain with kSecAttrAccessibleAfterFirstUnlock
Use for encrypting cached message content
```

## Performance Optimizations

### 1. Lazy Loading
```swift
// Only decrypt messages when scrolling into view
.onAppear {
    if decryptedContent == nil {
        decryptedContent = decrypt(ciphertext)
    }
}
```

### 2. Batch Operations
```swift
// Save messages in batches
func saveMessages(_ messages: [ConversationMessage]) {
    context.performBatchUpdate { batch in
        messages.forEach { batch.insert($0) }
    }
}
```

### 3. Background Context
```swift
// Don't block UI thread
Task.detached(priority: .background) {
    await cacheService.saveMessages(messages)
}
```

## Testing Strategy

### Unit Tests
- [ ] CacheService save/retrieve
- [ ] SecureCache encrypt/decrypt
- [ ] Sync conflict resolution
- [ ] TTL cleanup

### Integration Tests
- [ ] Online → Offline transition
- [ ] Offline → Online sync
- [ ] Large message list performance
- [ ] Cache size limits

### Manual Testing
- [ ] Enable airplane mode, verify messages visible
- [ ] Send message offline, verify queued
- [ ] Go online, verify message sends
- [ ] Delete conversation, verify cache cleared

## Rollout Plan

### Alpha (Internal Testing)
- Implement Phase 1-3
- Test with small user group
- Monitor cache size/performance

### Beta (Limited Release)
- Add Phase 4-5
- Monitor sync performance
- Gather user feedback

### Production
- Complete Phase 6
- Monitor metrics (cache hit rate, sync frequency)
- Optimize based on usage patterns

## Metrics to Track

```
- Cache hit rate (% of loads from cache vs API)
- Sync frequency (avg time between syncs)
- Cache size per user (avg MB used)
- Offline usage (% of app opens while offline)
- Sync queue size (pending messages to send)
```

## Migration Strategy

### Existing Users
```
1. Install update
2. Next app open: Trigger full sync
3. Download all conversations → cache
4. Download all recent messages (last 7 days) → cache
5. Enable offline mode
```

### Data Compatibility
```
- Keep UserDefaults for backwards compat (1 version)
- Migrate to Keychain in background
- Delete UserDefaults after migration confirmed
```

## Conclusion

This implementation will provide WhatsApp-level offline functionality while maintaining Safe Whisper's security model. Estimated timeline: 3-4 weeks for full implementation and testing.

Key Benefits:
✅ Instant app launch (no loading spinner)
✅ Full offline access to messages
✅ Background sync keeps data fresh
✅ Improved security (Keychain vs UserDefaults)
✅ Better user experience (no "Connection Error" screens)
