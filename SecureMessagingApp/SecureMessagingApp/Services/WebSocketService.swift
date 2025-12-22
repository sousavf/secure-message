import Foundation
import Combine

/**
 * WebSocket service for receiving real-time delivery notifications
 * Connects to backend STOMP WebSocket for MESSAGE_DELIVERED/MESSAGE_FAILED events
 */
class WebSocketService: ObservableObject {
    static let shared = WebSocketService()

    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private let messageSendingService = MessageSendingService.shared

    @Published var connectionStatus: ConnectionStatus = .disconnected

    enum ConnectionStatus {
        case connected
        case disconnected
        case connecting
        case error(String)
    }

    private init() {
        // Listen for network changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkConnected),
            name: .networkConnected,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkDisconnected),
            name: .networkDisconnected,
            object: nil
        )
    }

    /**
     * Connect to WebSocket server
     */
    func connect(deviceId: String) {
        guard !isConnected else {
            print("[WebSocket] Already connected")
            return
        }

        connectionStatus = .connecting

        // Construct WebSocket URL
        // Replace http:// with ws:// or https:// with wss://
        let baseURL = Config.baseURL
        let wsURL = baseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")

        guard let url = URL(string: "\(wsURL)/ws") else {
            print("[WebSocket] Invalid URL")
            connectionStatus = .error("Invalid WebSocket URL")
            return
        }

        print("[WebSocket] Connecting to: \(url.absoluteString)")

        // Create URLSession with WebSocket configuration
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)

        // Start receiving messages
        receiveMessage()

        // Connect
        webSocketTask?.resume()
        isConnected = true
        connectionStatus = .connected

        print("[WebSocket] Connected successfully")

        // Subscribe to user-specific queue for delivery notifications
        subscribeToNotifications(deviceId: deviceId)
    }

    /**
     * Disconnect from WebSocket
     */
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionStatus = .disconnected

        print("[WebSocket] Disconnected")
    }

    /**
     * Subscribe to user-specific notification queue
     * Sends STOMP SUBSCRIBE frame
     */
    private func subscribeToNotifications(deviceId: String) {
        let subscribeFrame = """
        SUBSCRIBE
        id:sub-0
        destination:/user/\(deviceId)/queue/notifications

        \0
        """

        sendMessage(subscribeFrame)
        print("[WebSocket] Subscribed to notifications for device: \(deviceId)")
    }

    /**
     * Send message over WebSocket
     */
    private func sendMessage(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)

        webSocketTask?.send(message) { error in
            if let error = error {
                print("[WebSocket] Send error: \(error)")
            }
        }
    }

    /**
     * Receive messages from WebSocket
     */
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)

                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }

                @unknown default:
                    print("[WebSocket] Unknown message type")
                }

                // Continue receiving
                self?.receiveMessage()

            case .failure(let error):
                print("[WebSocket] Receive error: \(error)")
                self?.connectionStatus = .error(error.localizedDescription)
                self?.isConnected = false
            }
        }
    }

    /**
     * Handle incoming WebSocket message
     * Parses STOMP frame and extracts JSON payload
     */
    private func handleMessage(_ message: String) {
        print("[WebSocket] Received: \(message)")

        // Parse STOMP frame
        // Format:
        // MESSAGE
        // destination:/user/device-123/queue/notifications
        //
        // {"type":"MESSAGE_DELIVERED","serverId":"...","messageId":"...","deliveredAt":"..."}
        // \0

        // Extract JSON payload (after empty line, before \0)
        let components = message.components(separatedBy: "\n\n")
        guard components.count >= 2 else {
            print("[WebSocket] Invalid STOMP frame format")
            return
        }

        let payload = components[1].trimmingCharacters(in: CharacterSet(charactersIn: "\0"))

        // Parse JSON payload
        guard let data = payload.data(using: .utf8) else {
            print("[WebSocket] Failed to convert payload to data")
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                handleNotification(json)
            }
        } catch {
            print("[WebSocket] JSON parse error: \(error)")
        }
    }

    /**
     * Handle delivery notification
     */
    private func handleNotification(_ json: [String: Any]) {
        guard let type = json["type"] as? String else {
            print("[WebSocket] Missing type field")
            return
        }

        print("[WebSocket] Notification type: \(type)")

        switch type {
        case "MESSAGE_DELIVERED":
            handleMessageDelivered(json)

        case "MESSAGE_FAILED":
            handleMessageFailed(json)

        case "NEW_MESSAGE":
            handleNewMessage(json)

        default:
            print("[WebSocket] Unknown notification type: \(type)")
        }
    }

    /**
     * Handle MESSAGE_DELIVERED notification
     * Updates message status from sent → delivered
     */
    private func handleMessageDelivered(_ json: [String: Any]) {
        guard let serverIdStr = json["serverId"] as? String,
              let serverId = UUID(uuidString: serverIdStr),
              let messageIdStr = json["messageId"] as? String,
              let messageId = UUID(uuidString: messageIdStr),
              let deliveredAtStr = json["deliveredAt"] as? String else {
            print("[WebSocket] Invalid MESSAGE_DELIVERED payload")
            return
        }

        // Parse ISO 8601 date
        let formatter = ISO8601DateFormatter()
        let deliveredAt = formatter.date(from: deliveredAtStr) ?? Date()

        messageSendingService.handleMessageDelivered(
            serverId: serverId,
            messageId: messageId,
            deliveredAt: deliveredAt
        )
    }

    /**
     * Handle MESSAGE_FAILED notification
     */
    private func handleMessageFailed(_ json: [String: Any]) {
        guard let serverIdStr = json["serverId"] as? String,
              let serverId = UUID(uuidString: serverIdStr) else {
            print("[WebSocket] Invalid MESSAGE_FAILED payload")
            return
        }

        messageSendingService.handleMessageFailed(serverId: serverId)
    }

    /**
     * Handle NEW_MESSAGE notification
     * Notifies UI to refresh conversation
     */
    private func handleNewMessage(_ json: [String: Any]) {
        guard let conversationIdStr = json["conversationId"] as? String,
              let conversationId = UUID(uuidString: conversationIdStr),
              let messageIdStr = json["messageId"] as? String,
              let messageId = UUID(uuidString: messageIdStr) else {
            print("[WebSocket] Invalid NEW_MESSAGE payload")
            return
        }

        print("[WebSocket] New message in conversation: \(conversationId), messageId: \(messageId)")

        // Post notification for UI to refresh
        NotificationCenter.default.post(
            name: .newMessageReceived,
            object: nil,
            userInfo: ["conversationId": conversationId, "messageId": messageId]
        )
    }

    // MARK: - Network Monitoring

    @objc private func networkConnected() {
        print("[WebSocket] Network connected, attempting reconnection...")
        // Reconnect logic can be added here if needed
    }

    @objc private func networkDisconnected() {
        print("[WebSocket] Network disconnected")
        disconnect()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        disconnect()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let newMessageReceived = Notification.Name("newMessageReceived")
}
