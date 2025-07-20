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
    let consumed: Bool?
}

struct APIError: Error, LocalizedError {
    let message: String
    let code: Int?
    
    var errorDescription: String? {
        return message
    }
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(Int)
    case messageConsumed
    case messageExpired
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
            return "This message has already been read"
        case .messageExpired:
            return "This message has expired"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}