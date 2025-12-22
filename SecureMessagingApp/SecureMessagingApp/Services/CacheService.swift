import CoreData
import Foundation

/**
 * Service for caching conversations and messages locally using Core Data
 * Provides WhatsApp-style offline functionality
 */
class CacheService {
    static let shared = CacheService()
    private let persistence = PersistenceController.shared

    // MARK: - Conversations

    /**
     * Save conversations to Core Data cache
     */
    func saveConversations(_ conversations: [Conversation]) {
        let context = persistence.container.viewContext

        for conversation in conversations {
            // Check if conversation already exists
            let fetchRequest: NSFetchRequest<CachedConversation> = CachedConversation.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", conversation.id as CVarArg)

            do {
                let existing = try context.fetch(fetchRequest)

                let cached: CachedConversation
                if let existingConversation = existing.first {
                    cached = existingConversation
                } else {
                    cached = CachedConversation(context: context)
                }

                cached.update(from: conversation)
            } catch {
                print("Error saving conversation: \(error)")
            }
        }

        persistence.save()
    }

    /**
     * Get all cached conversations
     */
    func getConversations() -> [Conversation] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedConversation> = CachedConversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let cached = try context.fetch(request)
            return cached.map { $0.toConversation() }
        } catch {
            print("Error fetching conversations: \(error)")
            return []
        }
    }

    /**
     * Get a specific conversation by ID
     */
    func getConversation(id: UUID) -> Conversation? {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedConversation> = CachedConversation.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let cached = try context.fetch(request).first {
                return cached.toConversation()
            }
        } catch {
            print("Error fetching conversation: \(error)")
        }

        return nil
    }

    // MARK: - Messages

    /**
     * Save a message to Core Data cache
     */
    func saveMessage(_ message: ConversationMessage, for conversationId: UUID) {
        let context = persistence.container.viewContext

        // Check if message already exists
        let fetchRequest: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", message.id as CVarArg)

        do {
            let existing = try context.fetch(fetchRequest)

            let cached: CachedMessage
            if let existingMessage = existing.first {
                cached = existingMessage
            } else {
                cached = CachedMessage(context: context)
            }

            cached.update(from: message)

            // Link to conversation if exists
            let convRequest: NSFetchRequest<CachedConversation> = CachedConversation.fetchRequest()
            convRequest.predicate = NSPredicate(format: "id == %@", conversationId as CVarArg)
            if let conversation = try context.fetch(convRequest).first {
                cached.conversation = conversation
            }

        } catch {
            print("Error saving message: \(error)")
        }

        persistence.save()
    }

    /**
     * Get all messages for a conversation
     */
    func getMessages(for conversationId: UUID) -> [ConversationMessage] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "conversationId == %@", conversationId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            let cached = try context.fetch(request)
            return cached.map { $0.toMessage() }
        } catch {
            print("Error fetching messages: \(error)")
            return []
        }
    }

    /**
     * Update message sync status (for delivery tracking)
     */
    func updateMessageStatus(_ id: UUID, status: SyncStatus, serverId: UUID? = nil) {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let cached = try context.fetch(request).first {
                cached.syncStatus = status.rawValue

                if let serverId = serverId {
                    cached.serverId = serverId
                }

                if status == .sent {
                    cached.sentAt = Date()
                } else if status == .delivered {
                    cached.deliveredAt = Date()
                } else if status == .read {
                    cached.readAt = Date()
                }

                persistence.save()
            }
        } catch {
            print("Error updating message status: \(error)")
        }
    }

    /**
     * Update message status by server ID (used when receiving WebSocket notifications)
     */
    func updateMessageStatusByServerId(_ serverId: UUID, messageId: UUID? = nil, status: SyncStatus) {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId as CVarArg)

        do {
            if let cached = try context.fetch(request).first {
                if let messageId = messageId {
                    // Update the final message ID when delivered
                    cached.id = messageId
                }

                cached.syncStatus = status.rawValue

                if status == .delivered {
                    cached.deliveredAt = Date()
                } else if status == .read {
                    cached.readAt = Date()
                }

                persistence.save()
            }
        } catch {
            print("Error updating message status by serverId: \(error)")
        }
    }

    /**
     * Get all pending messages (not yet sent to server)
     */
    func getPendingMessages() -> [ConversationMessage] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.pending.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            let cached = try context.fetch(request)
            return cached.map { $0.toMessage() }
        } catch {
            print("Error fetching pending messages: \(error)")
            return []
        }
    }

    /**
     * Delete a message from cache
     */
    func deleteMessage(_ id: UUID) {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let cached = try context.fetch(request).first {
                context.delete(cached)
                persistence.save()
            }
        } catch {
            print("Error deleting message: \(error)")
        }
    }

    /**
     * Delete a conversation and all its messages from cache
     */
    func deleteConversation(_ id: UUID) {
        let context = persistence.container.viewContext

        // Delete all messages in conversation
        let messageRequest: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        messageRequest.predicate = NSPredicate(format: "conversationId == %@", id as CVarArg)

        do {
            let messages = try context.fetch(messageRequest)
            for message in messages {
                context.delete(message)
            }

            // Delete conversation
            let convRequest: NSFetchRequest<CachedConversation> = CachedConversation.fetchRequest()
            convRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            if let conversation = try context.fetch(convRequest).first {
                context.delete(conversation)
            }

            persistence.save()
        } catch {
            print("Error deleting conversation: \(error)")
        }
    }
}
