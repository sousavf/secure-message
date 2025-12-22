import Foundation
import CoreData

extension CachedConversation {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedConversation> {
        return NSFetchRequest<CachedConversation>(entityName: "CachedConversation")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var initiatorUserId: UUID?
    @NSManaged public var status: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var expiresAt: Date?
    @NSManaged public var encryptionKey: String?  // Encrypted with device key
    @NSManaged public var localName: String?
    @NSManaged public var lastSyncedAt: Date?
    @NSManaged public var isCreatedByCurrentDevice: Bool
    @NSManaged public var messages: NSSet?
}

// MARK: Generated accessors for messages
extension CachedConversation {

    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: CachedMessage)

    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: CachedMessage)

    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)

    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)

}

extension CachedConversation : Identifiable {

}
