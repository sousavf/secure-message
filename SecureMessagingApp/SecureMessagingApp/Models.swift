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
    let ttlMinutes: Int?
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

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(Int)
    case messageConsumed
    case messageExpired
    case messageTooLarge(String)
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
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}