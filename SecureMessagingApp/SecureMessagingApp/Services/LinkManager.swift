import Foundation
import CryptoKit

class LinkManager {
    private let baseURL: String
    
    init(baseURL: String = "https://whisper.stratholme.eu/api") {
        self.baseURL = baseURL
    }
    
    func generateShareableLink(messageId: UUID, key: SymmetricKey) -> String {
        let keyString = CryptoManager.keyToBase64String(key)
        return "\(baseURL)/message/\(messageId.uuidString)#\(keyString)"
    }
    
    func parseLink(_ urlString: String) throws -> ParsedLink {
        guard let url = URL(string: urlString) else {
            throw LinkError.invalidURL
        }
        
        guard let fragment = url.fragment, !fragment.isEmpty else {
            throw LinkError.missingKey
        }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count >= 3,
              pathComponents[1] == "message",
              let messageId = UUID(uuidString: pathComponents[2]) else {
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
            return "Invalid message ID in URL"
        case .invalidKey:
            return "Invalid encryption key format"
        }
    }
}
