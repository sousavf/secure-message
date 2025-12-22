import Foundation
import Combine

/**
 * Service for managing offline message queue
 * Automatically retries pending messages when network is restored
 */
class OfflineQueueService: ObservableObject {
    static let shared = OfflineQueueService()

    private let cacheService = CacheService.shared
    private let messageSendingService = MessageSendingService.shared
    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()

    @Published var pendingMessageCount: Int = 0

    private init() {
        // Listen for network connection restored
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkConnected),
            name: .networkConnected,
            object: nil
        )

        // Monitor pending message count
        updatePendingCount()
    }

    /**
     * Process all pending messages
     * Called when network is restored or app comes to foreground
     */
    func processPendingMessages() {
        guard networkMonitor.isConnected else {
            print("[OfflineQueue] No network connection, skipping")
            return
        }

        let pendingMessages = cacheService.getPendingMessages()

        guard !pendingMessages.isEmpty else {
            print("[OfflineQueue] No pending messages")
            return
        }

        print("[OfflineQueue] Processing \(pendingMessages.count) pending messages")

        for message in pendingMessages {
            // Retry sending each message
            Task {
                await retryMessage(message)
            }
        }

        updatePendingCount()
    }

    /**
     * Retry sending a single message
     */
    private func retryMessage(_ message: ConversationMessage) async {
        guard let conversationId = message.conversationId,
              let ciphertext = message.ciphertext,
              let nonce = message.nonce,
              let tag = message.tag,
              let senderDeviceId = message.senderDeviceId else {
            print("[OfflineQueue] Invalid message data, cannot retry: \(message.id)")
            cacheService.updateMessageStatus(message.id, status: .failed)
            return
        }

        print("[OfflineQueue] Retrying message: \(message.id)")

        let encryptedMessage = EncryptedMessage(
            ciphertext: ciphertext,
            nonce: nonce,
            tag: tag
        )

        do {
            // Use MessageSendingService to resend
            // Note: This will create a new local ID, so we need to update the existing message instead
            let bufferedResponse = try await sendToBufferedEndpoint(
                conversationId: conversationId,
                encryptedMessage: encryptedMessage,
                messageType: message.messageType ?? .text,
                deviceId: senderDeviceId,
                fileName: message.fileName,
                fileSize: message.fileSize,
                fileMimeType: message.fileMimeType
            )

            // Update existing message with serverId and sent status
            cacheService.updateMessageStatus(
                message.id,
                status: .sent,
                serverId: bufferedResponse.serverId
            )

            print("[OfflineQueue] Message \(message.id) resent successfully, serverId: \(bufferedResponse.serverId)")

            // Post notification for UI update
            NotificationCenter.default.post(
                name: .messageSent,
                object: nil,
                userInfo: ["messageId": message.id, "serverId": bufferedResponse.serverId]
            )

        } catch {
            print("[OfflineQueue] Failed to retry message \(message.id): \(error)")

            // Keep as pending for next retry (don't mark as failed yet)
            // Will be retried on next network connection or manual trigger
        }
    }

    /**
     * Send to buffered endpoint (copied from MessageSendingService)
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
        guard let url = URL(string: "\(Config.baseURL)/api/conversations/\(conversationId.uuidString)/messages/buffered") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

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

        default:
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }

    /**
     * Update pending message count
     */
    private func updatePendingCount() {
        let pendingMessages = cacheService.getPendingMessages()
        DispatchQueue.main.async {
            self.pendingMessageCount = pendingMessages.count
        }
    }

    /**
     * Handle network reconnection
     */
    @objc private func networkConnected() {
        print("[OfflineQueue] Network connected, processing pending messages")
        processPendingMessages()
    }

    /**
     * Manually trigger retry (for debugging or user-initiated retry)
     */
    func manualRetry() {
        processPendingMessages()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
