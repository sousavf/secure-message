import CoreData
import Foundation

/**
 * Core Data persistence controller for offline message and conversation caching
 * Manages local database for WhatsApp-style offline functionality
 */
class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    // Preview container for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        // Add sample data for previews
        let sampleConversation = CachedConversation(context: viewContext)
        sampleConversation.id = UUID()
        sampleConversation.status = "ACTIVE"
        sampleConversation.createdAt = Date()
        sampleConversation.expiresAt = Date().addingTimeInterval(86400) // 24 hours

        do {
            try viewContext.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }

        return controller
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SecureMessaging")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error.localizedDescription)")
            }

            print("Core Data store loaded: \(description.url?.absoluteString ?? "unknown")")
        }

        // Automatically merge changes from parent context
        container.viewContext.automaticallyMergesChangesFromParent = true

        // Property-level conflict resolution (newer values win)
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /**
     * Save changes to Core Data
     * Call this after making changes to cached data
     */
    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
                print("Core Data saved successfully")
            } catch {
                print("Error saving Core Data: \(error.localizedDescription)")
            }
        }
    }

    /**
     * Perform a background task with a private context
     * Use for heavy operations to avoid blocking the UI
     */
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            block(context)

            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Background save failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /**
     * Delete all data from Core Data (for testing or logout)
     */
    func deleteAll() {
        let context = container.viewContext

        // Delete all CachedMessage entities
        let messageFetchRequest: NSFetchRequest<NSFetchRequestResult> = CachedMessage.fetchRequest()
        let messageDeleteRequest = NSBatchDeleteRequest(fetchRequest: messageFetchRequest)

        // Delete all CachedConversation entities
        let conversationFetchRequest: NSFetchRequest<NSFetchRequestResult> = CachedConversation.fetchRequest()
        let conversationDeleteRequest = NSBatchDeleteRequest(fetchRequest: conversationFetchRequest)

        do {
            try context.execute(messageDeleteRequest)
            try context.execute(conversationDeleteRequest)
            try context.save()
            print("All Core Data deleted")
        } catch {
            print("Failed to delete Core Data: \(error.localizedDescription)")
        }
    }
}
