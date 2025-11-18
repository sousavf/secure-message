import Foundation

/// Manages encryption keys for conversations
/// Keys are stored locally in UserDefaults, keyed by conversation ID
class KeyStore {
    static let shared = KeyStore()

    private let defaults = UserDefaults.standard
    private let keyPrefix = "conversation_key_"

    /// Store an encryption key for a conversation
    /// - Parameters:
    ///   - key: The encryption key (Base64 encoded string)
    ///   - conversationId: The conversation UUID
    func storeKey(_ key: String, for conversationId: UUID) {
        let storageKey = keyPrefix + conversationId.uuidString.lowercased()
        defaults.set(key, forKey: storageKey)
        print("[DEBUG] KeyStore - Stored key for conversation: \(conversationId)")
    }

    /// Retrieve an encryption key for a conversation
    /// - Parameter conversationId: The conversation UUID
    /// - Returns: The Base64 encoded encryption key, or nil if not found
    func retrieveKey(for conversationId: UUID) -> String? {
        let storageKey = keyPrefix + conversationId.uuidString.lowercased()
        let key = defaults.string(forKey: storageKey)
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
        let storageKey = keyPrefix + conversationId.uuidString.lowercased()
        defaults.removeObject(forKey: storageKey)
        print("[DEBUG] KeyStore - Deleted key for conversation: \(conversationId)")
    }

    /// Check if a key exists for a conversation
    /// - Parameter conversationId: The conversation UUID
    /// - Returns: True if a key is stored
    func hasKey(for conversationId: UUID) -> Bool {
        let storageKey = keyPrefix + conversationId.uuidString.lowercased()
        return defaults.string(forKey: storageKey) != nil
    }
}
