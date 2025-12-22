import Foundation
import CoreData

extension CachedMessage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedMessage> {
        return NSFetchRequest<CachedMessage>(entityName: "CachedMessage")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var serverId: UUID?
    @NSManaged public var conversationId: UUID?
    @NSManaged public var ciphertext: String?
    @NSManaged public var nonce: String?
    @NSManaged public var tag: String?
    @NSManaged public var messageType: String?
    @NSManaged public var syncStatus: String?
    @NSManaged public var sentAt: Date?
    @NSManaged public var deliveredAt: Date?
    @NSManaged public var readAt: Date?
    @NSManaged public var senderDeviceId: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var expiresAt: Date?
    @NSManaged public var consumed: Bool
    @NSManaged public var fileName: String?
    @NSManaged public var fileSize: Int32
    @NSManaged public var fileMimeType: String?
    @NSManaged public var fileUrl: String?
    @NSManaged public var conversation: CachedConversation?
}

extension CachedMessage : Identifiable {

}
