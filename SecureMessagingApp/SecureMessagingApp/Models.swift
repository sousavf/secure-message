import Foundation

struct EncryptedMessage: Codable {
    let ciphertext: String
    let nonce: String
    let tag: String
}

struct CreateMessageRequest: Codable {
    let ciphertext: String
    let nonce: String
    let tag: String
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
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, ciphertext, nonce, tag, createdAt, expiresAt, readAt, consumed
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

    var ttlHours: Int {
        let hours = Int(expiresAt.timeIntervalSince(createdAt) / 3600)
        return max(1, hours) // At least 1 hour
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

    // Local storage for encryption key (not sent to/from backend)
    var encryptionKey: String? = nil
    var decryptedContent: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, ciphertext, nonce, tag, createdAt, consumed, conversationId, expiresAt, readAt
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
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}