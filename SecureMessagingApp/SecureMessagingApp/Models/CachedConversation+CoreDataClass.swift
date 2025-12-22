import Foundation
import CoreData

@objc(CachedConversation)
public class CachedConversation: NSManagedObject {
    /**
     * Convert Core Data entity to app model
     */
    func toConversation() -> Conversation {
        var conversation = Conversation(
            id: self.id!,
            initiatorUserId: self.initiatorUserId,
            status: self.status ?? "ACTIVE",
            createdAt: self.createdAt!,
            expiresAt: self.expiresAt!
        )
        conversation.encryptionKey = self.encryptionKey
        conversation.localName = self.localName
        conversation.isCreatedByCurrentDevice = self.isCreatedByCurrentDevice
        return conversation
    }

    /**
     * Update Core Data entity from app model
     */
    func update(from conversation: Conversation) {
        self.id = conversation.id
        self.initiatorUserId = conversation.initiatorUserId
        self.status = conversation.status
        self.createdAt = conversation.createdAt
        self.expiresAt = conversation.expiresAt
        self.encryptionKey = conversation.encryptionKey
        self.localName = conversation.localName
        self.isCreatedByCurrentDevice = conversation.isCreatedByCurrentDevice
        self.lastSyncedAt = Date()
    }
}
