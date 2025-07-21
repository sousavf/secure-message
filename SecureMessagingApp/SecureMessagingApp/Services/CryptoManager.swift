import Foundation
import CryptoKit

class CryptoManager {
    
    private init() {}
    
    static func generateKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    static func keyToBase64String(_ key: SymmetricKey) -> String {
        return key.withUnsafeBytes { bytes in
            Data(bytes).base64URLEncodedString()
        }
    }
    
    static func keyFromBase64String(_ base64String: String) throws -> SymmetricKey {
        guard let keyData = Data(base64URLEncoded: base64String) else {
            throw CryptoError.invalidKey
        }
        return SymmetricKey(data: keyData)
    }
    
    static func encrypt(message: String, key: SymmetricKey) throws -> EncryptedMessage {
        guard let messageData = message.data(using: .utf8) else {
            throw CryptoError.invalidMessage
        }
        
        let sealedBox = try AES.GCM.seal(messageData, using: key)
        
        let nonce = sealedBox.nonce
        let ciphertext = sealedBox.ciphertext
        let tag = sealedBox.tag
        
        return EncryptedMessage(
            ciphertext: ciphertext.base64EncodedString(),
            nonce: nonce.withUnsafeBytes { Data($0).base64EncodedString() },
            tag: tag.base64EncodedString()
        )
    }
    
    static func decrypt(encryptedMessage: EncryptedMessage, key: SymmetricKey) throws -> String {
        guard let ciphertext = Data(base64Encoded: encryptedMessage.ciphertext),
              let nonceData = Data(base64Encoded: encryptedMessage.nonce),
              let tag = Data(base64Encoded: encryptedMessage.tag) else {
            throw CryptoError.invalidEncryptedData
        }
        
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        
        return decryptedString
    }
    
    static func securelyErase<T>(_ data: inout T) {
        withUnsafeMutableBytes(of: &data) { bytes in
            _ = bytes.initializeMemory(as: UInt8.self, repeating: 0)
        }
    }
}

enum CryptoError: Error, LocalizedError {
    case invalidKey
    case invalidMessage
    case invalidEncryptedData
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid encryption key"
        case .invalidMessage:
            return "Invalid whisper format"
        case .invalidEncryptedData:
            return "Invalid encrypted data"
        case .encryptionFailed:
            return "Failed to encrypt whisper"
        case .decryptionFailed:
            return "Failed to decrypt whisper"
        }
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        self.init(base64Encoded: base64)
    }
}