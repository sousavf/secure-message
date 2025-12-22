import Foundation

/// Manages encryption keys for conversations
/// Keys are now stored securely in iOS Keychain (hardware-backed when available)
/// Maintains backward compatibility with existing code
class KeyStore {
    static let shared = KeyStore()

    private let keychainService = KeychainService.shared
    private static var hasMigrated = false

    private init() {
        // Perform one-time migration from UserDefaults to Keychain
        if !KeyStore.hasMigrated {
            keychainService.migrateFromUserDefaults()
            KeyStore.hasMigrated = true
        }
    }

    /// Store an encryption key for a conversation
    /// - Parameters:
    ///   - key: The encryption key (Base64 encoded string)
    ///   - conversationId: The conversation UUID
    func storeKey(_ key: String, for conversationId: UUID) {
        let success = keychainService.storeKey(key, for: conversationId)
        if success {
            print("[DEBUG] KeyStore - Stored key for conversation: \(conversationId)")
        } else {
            print("[ERROR] KeyStore - Failed to store key for conversation: \(conversationId)")
        }
    }

    /// Retrieve an encryption key for a conversation
    /// - Parameter conversationId: The conversation UUID
    /// - Returns: The Base64 encoded encryption key, or nil if not found
    func retrieveKey(for conversationId: UUID) -> String? {
        let key = keychainService.retrieveKey(for: conversationId)
        if key != nil {
            print("[DEBUG] KeyStore - Retrieved key for conversation: \(conversationId)")
        } else {
            print("[DEBUG] KeyStore - No key found for conversation: \(conversationId)")
        }
        return key
    }

    /// Delete a stored key for a conversation
    /// - Parameter conversationId: The conversation UUID
    func deleteKey(for conversationId: UUID) {
        let success = keychainService.deleteKey(for: conversationId)
        if success {
            print("[DEBUG] KeyStore - Deleted key for conversation: \(conversationId)")
        } else {
            print("[ERROR] KeyStore - Failed to delete key for conversation: \(conversationId)")
        }
    }

    /// Check if a key exists for a conversation
    /// - Parameter conversationId: The conversation UUID
    /// - Returns: True if a key is stored
    func hasKey(for conversationId: UUID) -> Bool {
        return keychainService.retrieveKey(for: conversationId) != nil
    }
}
