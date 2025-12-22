import Foundation
import Combine

/**
 * Service for sending messages with delivery status tracking
 * Uses buffered endpoint for fast response and WhatsApp-style status indicators
 */
class MessageSendingService: ObservableObject {
    static let shared = MessageSendingService()

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    /**
     * Send message via buffered endpoint with delivery tracking
     * Returns local message ID immediately (status: pending)
     */
    func sendMessage(
        conversationId: UUID,
        encryptedMessage: EncryptedMessage,
        messageType: MessageType = .text,
        deviceId: String,
        fileName: String? = nil,
        fileSize: Int? = nil,
        fileMimeType: String? = nil
    ) async throws -> UUID {
        // Generate local message ID
        let localId = UUID()

        // Create message with pending status
        var message = ConversationMessage(
            id: localId,
            ciphertext: encryptedMessage.ciphertext,
            nonce: encryptedMessage.nonce,
            tag: encryptedMessage.tag,
            createdAt: Date(),
            consumed: false,
            conversationId: conversationId,
            expiresAt: nil, // Will be set from conversation
            readAt: nil,
            senderDeviceId: deviceId,
            messageType: messageType,
            fileName: fileName,
            fileSize: fileSize,
            fileMimeType: fileMimeType,
            fileUrl: nil
        )

        message.syncStatus = .pending

        // Save to local cache immediately (shows in UI with ⏰ indicator)
        cacheService.saveMessage(message, for: conversationId)

        print("[MessageSending] Message \(localId) saved locally with pending status")

        // Send to buffered endpoint in background
        Task {
            do {
                let bufferedResponse = try await sendToBufferedEndpoint(
                    conversationId: conversationId,
                    encryptedMessage: encryptedMessage,
                    messageType: messageType,
                    deviceId: deviceId,
                    fileName: fileName,
                    fileSize: fileSize,
                    fileMimeType: fileMimeType
                )

                // Update message with serverId and sent status
                message.serverId = bufferedResponse.serverId
                message.syncStatus = .sent
                message.sentAt = bufferedResponse.queuedAt

                cacheService.saveMessage(message, for: conversationId)

                print("[MessageSending] Message \(localId) sent to server, serverId: \(bufferedResponse.serverId)")

                // Post notification for UI update (⏰ → ✓)
                NotificationCenter.default.post(
                    name: .messageSent,
                    object: nil,
                    userInfo: ["messageId": localId, "serverId": bufferedResponse.serverId]
                )

            } catch {
                print("[MessageSending] Failed to send message \(localId): \(error)")

                // Update status to failed
                cacheService.updateMessageStatus(localId, status: .failed)

                // Post notification for UI update (show error)
                NotificationCenter.default.post(
                    name: .messageFailed,
                    object: nil,
                    userInfo: ["messageId": localId, "error": error]
                )
            }
        }

        return localId
    }

    /**
     * Send to buffered endpoint
     */
    private func sendToBufferedEndpoint(
        conversationId: UUID,
        encryptedMessage: EncryptedMessage,
        messageType: MessageType,
        deviceId: String,
        fileName: String?,
        fileSize: Int?,
        fileMimeType: String?
    ) async throws -> MessageBufferedResponse {
        guard let url = URL(string: "\(apiService.baseURL)/api/conversations/\(conversationId.uuidString)/messages/buffered") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        // Create request body
        var createRequest = CreateMessageRequest(
            ciphertext: encryptedMessage.ciphertext,
            nonce: encryptedMessage.nonce,
            tag: encryptedMessage.tag
        )
        createRequest.messageType = messageType

        request.httpBody = try JSONEncoder().encode(createRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }

        switch httpResponse.statusCode {
        case 202: // Accepted
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let bufferedResponse = try decoder.decode(MessageBufferedResponse.self, from: data)
            return bufferedResponse

        case 404:
            throw NetworkError.conversationNotFound

        case 413:
            let errorMessage = httpResponse.value(forHTTPHeaderField: "X-Error-Message") ?? "Message too large"
            throw NetworkError.messageTooLarge(errorMessage)

        case 503:
            throw NetworkError.serverError(503) // Service unavailable (Redis down?)

        default:
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }

    /**
     * Handle MESSAGE_DELIVERED WebSocket notification
     * Updates message status from sent → delivered (✓ → ✓✓)
     */
    func handleMessageDelivered(serverId: UUID, messageId: UUID, deliveredAt: Date) {
        cacheService.updateMessageStatusByServerId(serverId, messageId: messageId, status: .delivered)

        print("[MessageSending] Message delivered: serverId=\(serverId), messageId=\(messageId)")

        // Post notification for UI update
        NotificationCenter.default.post(
            name: .messageDelivered,
            object: nil,
            userInfo: ["serverId": serverId, "messageId": messageId, "deliveredAt": deliveredAt]
        )
    }

    /**
     * Handle MESSAGE_FAILED WebSocket notification
     */
    func handleMessageFailed(serverId: UUID) {
        // Find message by serverId and mark as failed
        cacheService.updateMessageStatusByServerId(serverId, status: .failed)

        print("[MessageSending] Message failed: serverId=\(serverId)")

        // Post notification for UI update
        NotificationCenter.default.post(
            name: .messageFailed,
            object: nil,
            userInfo: ["serverId": serverId]
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let messageSent = Notification.Name("messageSent")
    static let messageDelivered = Notification.Name("messageDelivered")
    static let messageFailed = Notification.Name("messageFailed")
}

// MARK: - APIService Extension for baseURL access
extension APIService {
    var baseURL: String {
        return Config.baseURL
    }
}
