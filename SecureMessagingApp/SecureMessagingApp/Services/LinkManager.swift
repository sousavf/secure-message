import Foundation
import CryptoKit

class LinkManager {
    private let baseURL: String
    
    init(baseURL: String = Config.baseURL) {
        self.baseURL = baseURL
    }
    
    func generateShareableLink(messageId: UUID, key: SymmetricKey) -> String {
        let keyString = CryptoManager.keyToBase64String(key)
        return "\(baseURL)/\(messageId.uuidString)/preview#\(keyString)"
    }
    
    func generateDirectLink(messageId: UUID, key: SymmetricKey) -> String {
        let keyString = CryptoManager.keyToBase64String(key)
        return "\(baseURL)/\(messageId.uuidString)#\(keyString)"
    }
    
    func parseLink(_ urlString: String) throws -> ParsedLink {
        guard let url = URL(string: urlString) else {
            throw LinkError.invalidURL
        }
        
        guard let fragment = url.fragment, !fragment.isEmpty else {
            throw LinkError.missingKey
        }
        
        let pathComponents = url.pathComponents
        
        // Handle both direct links and preview links
        var messageIdString: String?
        
        if pathComponents.count >= 2 {
            // Direct link: /{id}
            if pathComponents.count == 2 {
                messageIdString = pathComponents[1]
            }
            // Preview link: /{id}/preview
            else if pathComponents.count == 3 && pathComponents[2] == "preview" {
                messageIdString = pathComponents[1]
            }
        }
        
        guard let messageIdStr = messageIdString,
              let messageId = UUID(uuidString: messageIdStr) else {
            throw LinkError.invalidMessageID
        }
        
        let key = try CryptoManager.keyFromBase64String(fragment)
        
        return ParsedLink(messageId: messageId, key: key)
    }
    
    func isValidSecureMessagingLink(_ urlString: String) -> Bool {
        do {
            _ = try parseLink(urlString)
            return true
        } catch {
            return false
        }
    }
}

struct ParsedLink {
    let messageId: UUID
    let key: SymmetricKey
}

enum LinkError: Error, LocalizedError {
    case invalidURL
    case missingKey
    case invalidMessageID
    case invalidKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL format"
        case .missingKey:
            return "No encryption key found in URL"
        case .invalidMessageID:
            return "Invalid whisper ID in URL"
        case .invalidKey:
            return "Invalid encryption key format"
        }
    }
}
