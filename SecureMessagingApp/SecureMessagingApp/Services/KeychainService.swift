import Foundation
import Security

/**
 * Secure keychain service for storing encryption keys
 * Replaces UserDefaults-based KeyStore with iOS Keychain (hardware-backed when available)
 */
class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.sousavf.securemessaging"

    private init() {}

    // MARK: - Conversation Keys

    /**
     * Store encryption key for a conversation
     */
    func storeKey(_ key: String, for conversationId: UUID) -> Bool {
        let keyData = key.data(using: .utf8)!
        let account = "conversation_\(conversationId.uuidString)"

        return saveToKeychain(keyData, service: serviceName, account: account)
    }

    /**
     * Retrieve encryption key for a conversation
     */
    func retrieveKey(for conversationId: UUID) -> String? {
        let account = "conversation_\(conversationId.uuidString)"

        guard let keyData = loadFromKeychain(service: serviceName, account: account) else {
            return nil
        }

        return String(data: keyData, encoding: .utf8)
    }

    /**
     * Delete encryption key for a conversation
     */
    func deleteKey(for conversationId: UUID) -> Bool {
        let account = "conversation_\(conversationId.uuidString)"
        return deleteFromKeychain(service: serviceName, account: account)
    }

    // MARK: - Device ID

    /**
     * Store device ID securely
     */
    func storeDeviceId(_ deviceId: String) -> Bool {
        let deviceIdData = deviceId.data(using: .utf8)!
        return saveToKeychain(deviceIdData, service: serviceName, account: "deviceId")
    }

    /**
     * Retrieve device ID
     */
    func retrieveDeviceId() -> String? {
        guard let deviceIdData = loadFromKeychain(service: serviceName, account: "deviceId") else {
            return nil
        }

        return String(data: deviceIdData, encoding: .utf8)
    }

    // MARK: - Generic Keychain Operations

    /**
     * Save data to keychain
     */
    private func saveToKeychain(_ data: Data, service: String, account: String) -> Bool {
        // Build query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("[Keychain] Successfully stored item for account: \(account)")
            return true
        } else {
            print("[Keychain] Failed to store item for account: \(account), status: \(status)")
            return false
        }
    }

    /**
     * Load data from keychain
     */
    private func loadFromKeychain(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        } else if status == errSecItemNotFound {
            print("[Keychain] Item not found for account: \(account)")
            return nil
        } else {
            print("[Keychain] Failed to load item for account: \(account), status: \(status)")
            return nil
        }
    }

    /**
     * Delete data from keychain
     */
    private func deleteFromKeychain(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            print("[Keychain] Successfully deleted item for account: \(account)")
            return true
        } else {
            print("[Keychain] Failed to delete item for account: \(account), status: \(status)")
            return false
        }
    }

    /**
     * Delete all keys (for testing or logout)
     */
    func deleteAllKeys() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            print("[Keychain] Successfully deleted all keys")
            return true
        } else {
            print("[Keychain] Failed to delete all keys, status: \(status)")
            return false
        }
    }

    // MARK: - Migration from UserDefaults

    /**
     * Migrate keys from old KeyStore (UserDefaults) to Keychain
     * Call this once during app upgrade
     */
    func migrateFromUserDefaults() {
        print("[Keychain] Starting migration from UserDefaults...")

        // Get all keys from UserDefaults
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys

        var migratedCount = 0

        for key in allKeys {
            // Check if it's a conversation key (format: "conversation_UUID")
            if key.hasPrefix("conversation_"), let value = defaults.string(forKey: key) {
                // Extract UUID
                let uuidString = key.replacingOccurrences(of: "conversation_", with: "")
                if let conversationId = UUID(uuidString: uuidString) {
                    // Store in keychain
                    if storeKey(value, for: conversationId) {
                        // Remove from UserDefaults
                        defaults.removeObject(forKey: key)
                        migratedCount += 1
                        print("[Keychain] Migrated key for conversation: \(conversationId)")
                    }
                }
            } else if key == "deviceId", let value = defaults.string(forKey: key) {
                // Migrate device ID
                if storeDeviceId(value) {
                    defaults.removeObject(forKey: key)
                    migratedCount += 1
                    print("[Keychain] Migrated device ID")
                }
            }
        }

        print("[Keychain] Migration complete. Migrated \(migratedCount) keys.")
    }
}
