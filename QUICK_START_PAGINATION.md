# Quick Start: Using Message Pagination

## Overview

Message pagination is now available in the Safe Whisper backend. Use this to efficiently load messages in conversations, supporting infinite scroll patterns.

## API Usage

### 1. Initial Load (Get First Page)

```bash
curl -X GET "http://localhost:8687/api/conversations/{conversationId}/messages?limit=50" \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "messages": [
    {
      "id": "uuid",
      "ciphertext": "...",
      "nonce": "...",
      "tag": "...",
      "createdAt": "2025-11-21T13:00:00",
      "expiresAt": "2025-11-22T13:00:00",
      "senderDeviceId": "device-123"
    },
    ...50 messages total...
  ],
  "hasMore": true,
  "nextCursor": "2025-11-21T12:50:00",
  "pageSize": 50
}
```

### 2. Load More Messages (Pagination)

Once user scrolls to end, use the `nextCursor` from previous response:

```bash
curl -X GET "http://localhost:8687/api/conversations/{conversationId}/messages?limit=50&cursor=2025-11-21T12:50:00" \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "messages": [
    ...next 50 messages...
  ],
  "hasMore": false,  // No more messages to load
  "nextCursor": null,
  "pageSize": 50
}
```

## Parameters

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `limit` | integer | No | 50 | Messages per page (max 100) |
| `cursor` | ISO-8601 string | No | - | Timestamp from previous `nextCursor` |
| `since` | ISO-8601 string | No | - | For polling (alternative to pagination) |

## iOS Implementation Example

### Swift Code for Infinite Scroll

```swift
var messages: [MessageResponse] = []
var currentCursor: LocalDateTime? = nil
var isLoadingMore = false
var hasMore = true

func loadFirstPage(conversationId: UUID) async {
    let response = try await apiService.getConversationMessages(
        conversationId: conversationId,
        limit: 50,
        cursor: nil
    )

    messages = response.messages
    currentCursor = response.nextCursor
    hasMore = response.hasMore
}

func loadMoreMessages(conversationId: UUID) async {
    guard !isLoadingMore, hasMore, let cursor = currentCursor else { return }

    isLoadingMore = true
    defer { isLoadingMore = false }

    let response = try await apiService.getConversationMessages(
        conversationId: conversationId,
        limit: 50,
        cursor: cursor
    )

    messages.append(contentsOf: response.messages)
    currentCursor = response.nextCursor
    hasMore = response.hasMore
}

// Call when ScrollView reaches bottom
func onScrollToBottom(conversationId: UUID) {
    Task {
        await loadMoreMessages(conversationId: conversationId)
    }
}
```

## Backward Compatibility

The API maintains backward compatibility. Old clients can still use non-paginated requests:

```bash
# Old way (without limit parameter) - still works but not recommended
curl -X GET "http://localhost:8687/api/conversations/{conversationId}/messages"

# Returns all messages (WARNING: slow for large conversations)
```

## Performance Comparison

### Without Pagination (Old)
- **Time to load 1000 messages**: 2-5 seconds
- **Memory**: ~50MB on client
- **Network**: Fetches all messages

### With Pagination (New)
- **Time to load first 50**: 50-100ms
- **Memory**: ~2.5MB on client (scales with page size)
- **Network**: Fetches only needed messages

## Best Practices

1. **Use reasonable page sizes**
   ```
   - Desktop: 50-100 messages
   - Mobile: 20-50 messages
   ```

2. **Handle errors gracefully**
   ```swift
   do {
       let response = try await loadMoreMessages()
   } catch {
       // Show error to user
       // Allow retry with same cursor
   }
   ```

3. **Avoid unnecessary requests**
   ```swift
   // Only load more if:
   // 1. Not already loading
   // 2. User scrolled to bottom
   // 3. hasMore is true
   ```

4. **Cache messages on client**
   ```swift
   // Store messages in local cache
   // Don't re-fetch if already loaded
   ```

## Monitoring

Check if pagination is working:

```bash
# Check metrics
curl http://localhost:8687/actuator/prometheus | grep message_retrieval

# Should show increasing count for:
# app_messages_retrieved_total
# app_message_retrieval_time (latency)
```

## Troubleshooting

### No messages returned
- Verify conversation exists: `GET /api/conversations/{conversationId}`
- Check conversation is not expired
- Verify device has permission to access conversation

### Slow pagination
- Check backend metrics: `/actuator/prometheus`
- Verify indexes were created (see `MONITORING_AND_METRICS.md`)
- Check database query logs for slow queries

### NextCursor is null but hasMore is true
- This shouldn't happen - report if seen
- May indicate empty result set

## API Limits

- **Max messages per request**: 100
- **Default page size**: 50
- **Cursor timestamp format**: ISO-8601 (e.g., `2025-11-21T13:00:00`)
- **Pagination timeout**: 60 seconds

## Related Documentation

- Full implementation: See `PHASE_1_OPTIMIZATION_SUMMARY.md`
- Monitoring setup: See `MONITORING_AND_METRICS.md`
- Architecture details: See `ARCHITECTURE_AND_SCALABILITY_PLAN.md`
