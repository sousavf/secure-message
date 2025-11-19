import Foundation

/// Manages local conversation names
/// Names are stored locally in UserDefaults, keyed by conversation ID
/// These names are never sent to the backend - each user can have different names for the same conversation
class ConversationNameStore {
    static let shared = ConversationNameStore()

    private let defaults = UserDefaults.standard
    private let namePrefix = "conversation_name_"

    /// Store a local name for a conversation
    /// - Parameters:
    ///   - name: The conversation name (user-friendly display name)
    ///   - conversationId: The conversation UUID
    func storeName(_ name: String, for conversationId: UUID) {
        let storageKey = namePrefix + conversationId.uuidString.lowercased()
        // Only store if not empty
        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
            defaults.set(name, forKey: storageKey)
            print("[DEBUG] ConversationNameStore - Stored name '\(name)' for conversation: \(conversationId)")
        } else {
            // If empty, delete the name (use default)
            defaults.removeObject(forKey: storageKey)
            print("[DEBUG] ConversationNameStore - Cleared name for conversation: \(conversationId)")
        }
    }

    /// Retrieve a local name for a conversation
    /// - Parameter conversationId: The conversation UUID
    /// - Returns: The custom name, or nil if not found (use default)
    func retrieveName(for conversationId: UUID) -> String? {
        let storageKey = namePrefix + conversationId.uuidString.lowercased()
        let name = defaults.string(forKey: storageKey)
        if name != nil {
            print("[DEBUG] ConversationNameStore - Retrieved name for conversation: \(conversationId)")
        } else {
            print("[DEBUG] ConversationNameStore - No custom name found for conversation: \(conversationId)")
        }
        return name
    }

    /// Delete a stored name for a conversation
    /// - Parameter conversationId: The conversation UUID
    func deleteName(for conversationId: UUID) {
        let storageKey = namePrefix + conversationId.uuidString.lowercased()
        defaults.removeObject(forKey: storageKey)
        print("[DEBUG] ConversationNameStore - Deleted name for conversation: \(conversationId)")
    }

    /// Check if a custom name exists for a conversation
    /// - Parameter conversationId: The conversation UUID
    /// - Returns: True if a custom name is stored
    func hasCustomName(for conversationId: UUID) -> Bool {
        let storageKey = namePrefix + conversationId.uuidString.lowercased()
        return defaults.string(forKey: storageKey) != nil
    }

    /// Get display name for a conversation (custom name or default)
    /// - Parameters:
    ///   - conversationId: The conversation UUID
    ///   - defaultName: The default name if no custom name exists
    /// - Returns: Custom name if exists, otherwise defaultName
    func getDisplayName(for conversationId: UUID, defaultName: String = "Private Conversation") -> String {
        return retrieveName(for: conversationId) ?? defaultName
    }
}
