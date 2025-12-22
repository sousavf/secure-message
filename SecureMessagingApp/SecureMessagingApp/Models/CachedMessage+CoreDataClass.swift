import Foundation
import CoreData

@objc(CachedMessage)
public class CachedMessage: NSManagedObject {
    /**
     * Convert Core Data entity to app model
     */
    func toMessage() -> ConversationMessage {
        var message = ConversationMessage(
            id: self.id!,
            ciphertext: self.ciphertext,
            nonce: self.nonce,
            tag: self.tag,
            createdAt: self.createdAt,
            consumed: self.consumed,
            conversationId: self.conversationId,
            expiresAt: self.expiresAt,
            readAt: self.readAt,
            senderDeviceId: self.senderDeviceId,
            messageType: MessageType(rawValue: self.messageType ?? "TEXT"),
            fileName: self.fileName,
            fileSize: self.fileSize as? Int,
            fileMimeType: self.fileMimeType,
            fileUrl: self.fileUrl
        )

        // Set delivery tracking fields
        message.serverId = self.serverId
        if let statusRaw = self.syncStatus, let status = SyncStatus(rawValue: statusRaw) {
            message.syncStatus = status
        }
        message.sentAt = self.sentAt
        message.deliveredAt = self.deliveredAt

        return message
    }

    /**
     * Update Core Data entity from app model
     */
    func update(from message: ConversationMessage) {
        self.id = message.id
        self.serverId = message.serverId
        self.conversationId = message.conversationId
        self.ciphertext = message.ciphertext
        self.nonce = message.nonce
        self.tag = message.tag
        self.messageType = message.messageType?.rawValue
        self.syncStatus = message.syncStatus.rawValue
        self.sentAt = message.sentAt
        self.deliveredAt = message.deliveredAt
        self.readAt = message.readAt
        self.senderDeviceId = message.senderDeviceId
        self.createdAt = message.createdAt
        self.expiresAt = message.expiresAt
        self.consumed = message.consumed
        self.fileName = message.fileName
        self.fileSize = message.fileSize as? Int32
        self.fileMimeType = message.fileMimeType
        self.fileUrl = message.fileUrl
    }
}

// Helper initializer for ConversationMessage
extension ConversationMessage {
    init(id: UUID, ciphertext: String?, nonce: String?, tag: String?,
         createdAt: Date?, consumed: Bool, conversationId: UUID?,
         expiresAt: Date?, readAt: Date?, senderDeviceId: String?,
         messageType: MessageType?, fileName: String?, fileSize: Int?,
         fileMimeType: String?, fileUrl: String?) {
        self.id = id
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.tag = tag
        self.createdAt = createdAt
        self.consumed = consumed
        self.conversationId = conversationId
        self.expiresAt = expiresAt
        self.readAt = readAt
        self.senderDeviceId = senderDeviceId
        self.messageType = messageType
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileMimeType = fileMimeType
        self.fileUrl = fileUrl
    }
}
