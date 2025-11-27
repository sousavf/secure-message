import Foundation

struct EncryptedMessage: Codable {
    let ciphertext: String
    let nonce: String
    let tag: String
}

enum MessageType: String, Codable {
    case text = "TEXT"
    case sticker = "STICKER"
    case image = "IMAGE"
    case file = "FILE"
}

struct CreateMessageRequest: Codable {
    let ciphertext: String
    let nonce: String
    let tag: String
    var messageType: MessageType = .text
}

struct MessageResponse: Codable {
    let id: UUID
    let ciphertext: String?
    let nonce: String?
    let tag: String?
    let createdAt: Date?
    let expiresAt: Date?
    let readAt: Date?
    let consumed: Bool
    let messageType: MessageType?
    
    // Handle the boolean properly - backend sends "consumed" as boolean, not optional
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        ciphertext = try container.decodeIfPresent(String.self, forKey: .ciphertext)
        nonce = try container.decodeIfPresent(String.self, forKey: .nonce)
        tag = try container.decodeIfPresent(String.self, forKey: .tag)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        consumed = try container.decodeIfPresent(Bool.self, forKey: .consumed) ?? false
        messageType = try container.decodeIfPresent(MessageType.self, forKey: .messageType)
    }

    private enum CodingKeys: String, CodingKey {
        case id, ciphertext, nonce, tag, createdAt, expiresAt, readAt, consumed, messageType
    }
}

struct APIError: Error, LocalizedError {
    let message: String
    let code: Int?
    
    var errorDescription: String? {
        return message
    }
}

struct MessageContent: Codable {
    let text: String?
    let image: String?
    let imageType: String?
}

// MARK: - Conversation Models

struct Conversation: Identifiable, Codable {
    let id: UUID
    let initiatorUserId: UUID?
    let status: String
    let createdAt: Date
    let expiresAt: Date
    // Note: encryptionKey is NOT transmitted over the wire
    // It's generated and stored locally on the client only
    var encryptionKey: String? // Master encryption key stored locally only (not from backend)
    // Track whether this conversation was created by the current device (initiator) or joined (secondary)
    // This is computed locally and not transmitted
    var isCreatedByCurrentDevice: Bool = true
    // Local-only custom name for this conversation (never transmitted to backend)
    // Each user/phone can have a different name for the same conversation
    var localName: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, initiatorUserId, status, createdAt, expiresAt
    }

    // Regular initializer for creating Conversation instances directly (non-Codable)
    init(id: UUID, initiatorUserId: UUID?, status: String, createdAt: Date, expiresAt: Date) {
        self.id = id
        self.initiatorUserId = initiatorUserId
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.encryptionKey = nil
        self.isCreatedByCurrentDevice = true
        self.localName = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        initiatorUserId = try container.decodeIfPresent(UUID.self, forKey: .initiatorUserId)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        encryptionKey = nil
        isCreatedByCurrentDevice = true // Default to true, will be set by the app
        localName = nil // Will be loaded from ConversationNameStore
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(initiatorUserId, forKey: .initiatorUserId)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(expiresAt, forKey: .expiresAt)
    }

    var ttlHours: Int {
        // Calculate hours as double first, then round to nearest integer
        let hours = expiresAt.timeIntervalSince(createdAt) / 3600
        // Use proper rounding instead of truncation to avoid off-by-one errors
        let roundedHours = Int(hours.rounded())
        return max(1, roundedHours) // At least 1 hour
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var timeRemaining: String {
        let remaining = expiresAt.timeIntervalSince(Date())
        if remaining <= 0 {
            return "Expired"
        }
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct ConversationMessage: Identifiable, Codable {
    let id: UUID
    let ciphertext: String?
    let nonce: String?
    let tag: String?
    let createdAt: Date?
    let consumed: Bool
    let conversationId: UUID?
    let expiresAt: Date?
    let readAt: Date?
    let senderDeviceId: String?  // Track who sent this message
    var messageType: MessageType?

    // File metadata (only populated for file/image messages)
    let fileName: String?
    let fileSize: Int?
    let fileMimeType: String?
    let fileUrl: String?

    // Local storage for encryption key and decrypted content (not sent to/from backend)
    var encryptionKey: String? = nil
    var decryptedContent: String? = nil
    var downloadedFileData: Data? = nil  // Decrypted file data cached locally

    enum CodingKeys: String, CodingKey {
        case id, ciphertext, nonce, tag, createdAt, consumed, conversationId, expiresAt, readAt, senderDeviceId, messageType
        case fileName, fileSize, fileMimeType, fileUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ciphertext = try container.decodeIfPresent(String.self, forKey: .ciphertext)
        nonce = try container.decodeIfPresent(String.self, forKey: .nonce)
        tag = try container.decodeIfPresent(String.self, forKey: .tag)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        consumed = try container.decode(Bool.self, forKey: .consumed)
        conversationId = try container.decodeIfPresent(UUID.self, forKey: .conversationId)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        senderDeviceId = try container.decodeIfPresent(String.self, forKey: .senderDeviceId)
        messageType = try container.decodeIfPresent(MessageType.self, forKey: .messageType)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        fileSize = try container.decodeIfPresent(Int.self, forKey: .fileSize)
        fileMimeType = try container.decodeIfPresent(String.self, forKey: .fileMimeType)
        fileUrl = try container.decodeIfPresent(String.self, forKey: .fileUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(ciphertext, forKey: .ciphertext)
        try container.encodeIfPresent(nonce, forKey: .nonce)
        try container.encodeIfPresent(tag, forKey: .tag)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encode(consumed, forKey: .consumed)
        try container.encodeIfPresent(conversationId, forKey: .conversationId)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(readAt, forKey: .readAt)
        try container.encodeIfPresent(senderDeviceId, forKey: .senderDeviceId)
        try container.encodeIfPresent(messageType, forKey: .messageType)
        try container.encodeIfPresent(fileName, forKey: .fileName)
        try container.encodeIfPresent(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(fileMimeType, forKey: .fileMimeType)
        try container.encodeIfPresent(fileUrl, forKey: .fileUrl)
    }

    // Check if message is expired
    var isExpired: Bool {
        if let expiresAt = expiresAt {
            return expiresAt < Date()
        }
        return false
    }
}

struct CreateConversationRequest: Codable {
    let ttlHours: Int
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(Int)
    case messageConsumed
    case messageExpired
    case messageTooLarge(String)
    case conversationExpired
    case conversationNotFound
    case linkAlreadyConsumed(String)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .messageConsumed:
            return "This whisper has already been read"
        case .messageExpired:
            return "This whisper has expired"
        case .messageTooLarge(let message):
            return message
        case .conversationExpired:
            return "This conversation has expired"
        case .conversationNotFound:
            return "Conversation not found"
        case .linkAlreadyConsumed(let message):
            return message
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
