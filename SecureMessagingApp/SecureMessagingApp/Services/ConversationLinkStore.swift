import Foundation

/// Manages local persistence of conversation links
/// Stores the join links for conversations so users can resume them later
class ConversationLinkStore {
    static let shared = ConversationLinkStore()

    private let defaults = UserDefaults.standard
    private let conversationLinksKey = "conversation_links"

    struct ConversationLink: Codable {
        let conversationId: UUID
        let link: String
        let savedDate: Date
    }

    /// Save a conversation link locally
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - link: The full conversation link (with encryption key in fragment)
    func saveLink(_ conversationId: UUID, link: String) {
        print("[DEBUG] ConversationLinkStore - Saving link for conversation: \(conversationId)")

        do {
            var links = loadAllLinks()

            // Remove if already exists (to update)
            links.removeAll { $0.conversationId == conversationId }

            // Add the new link
            links.append(ConversationLink(conversationId: conversationId, link: link, savedDate: Date()))

            // Encode and save
            let encoded = try JSONEncoder().encode(links)
            defaults.set(encoded, forKey: conversationLinksKey)

            print("[DEBUG] ConversationLinkStore - Link saved. Total links: \(links.count)")
        } catch {
            print("[ERROR] ConversationLinkStore - Failed to save link: \(error)")
        }
    }

    /// Load all saved conversation links
    /// - Returns: Array of conversation links, or empty array if none found
    func loadAllLinks() -> [ConversationLink] {
        guard let data = defaults.data(forKey: conversationLinksKey) else {
            print("[DEBUG] ConversationLinkStore - No saved links found")
            return []
        }

        do {
            let links = try JSONDecoder().decode([ConversationLink].self, from: data)
            print("[DEBUG] ConversationLinkStore - Loaded \(links.count) links from storage")
            return links
        } catch {
            print("[ERROR] ConversationLinkStore - Failed to decode links: \(error)")
            return []
        }
    }

    /// Load a specific conversation link
    /// - Parameter conversationId: The conversation ID
    /// - Returns: The conversation link if found, nil otherwise
    func loadLink(for conversationId: UUID) -> ConversationLink? {
        let links = loadAllLinks()
        let link = links.first { $0.conversationId == conversationId }
        if link != nil {
            print("[DEBUG] ConversationLinkStore - Found link for conversation: \(conversationId)")
        } else {
            print("[DEBUG] ConversationLinkStore - No link found for conversation: \(conversationId)")
        }
        return link
    }

    /// Delete a conversation link locally
    /// - Parameter conversationId: The conversation ID
    func deleteLink(for conversationId: UUID) {
        print("[DEBUG] ConversationLinkStore - Deleting link for conversation: \(conversationId)")

        do {
            var links = loadAllLinks()
            links.removeAll { $0.conversationId == conversationId }

            let encoded = try JSONEncoder().encode(links)
            defaults.set(encoded, forKey: conversationLinksKey)

            print("[DEBUG] ConversationLinkStore - Link deleted. Remaining: \(links.count)")
        } catch {
            print("[ERROR] ConversationLinkStore - Failed to delete link: \(error)")
        }
    }

    /// Check if we have a saved link for a conversation
    /// - Parameter conversationId: The conversation ID
    /// - Returns: True if link exists locally
    func hasLink(for conversationId: UUID) -> Bool {
        return loadLink(for: conversationId) != nil
    }

    /// Get all conversation IDs we have links for
    /// - Returns: Array of conversation IDs
    func getAllConversationIds() -> [UUID] {
        return loadAllLinks().map { $0.conversationId }
    }

    /// Clear all saved links
    func clearAll() {
        print("[DEBUG] ConversationLinkStore - Clearing all links")
        defaults.removeObject(forKey: conversationLinksKey)
    }

    /// Get count of saved links
    /// - Returns: Number of saved conversation links
    func getLinkCount() -> Int {
        return loadAllLinks().count
    }
}
