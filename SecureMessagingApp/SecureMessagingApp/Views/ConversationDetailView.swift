import SwiftUI
import CryptoKit

struct ConversationDetailView: View {
    @State var conversation: Conversation
    var deviceId: String
    var onUpdate: () -> Void

    @StateObject private var apiService = APIService.shared
    @State private var messages: [ConversationMessage] = []
    @State private var messageText: String = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var shareLink: String = ""
    @State private var showShareModal = false
    @FocusState private var messageFieldFocused: Bool

    // Polling state
    @State private var pollTimer: Timer?
    @State private var lastMessageTimestamp: Date?
    private let pollInterval: TimeInterval = 5.0 // Poll every 5 seconds

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Messages List
                    if messages.isEmpty && !isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.indigo)
                            Text("No Messages Yet")
                                .font(.headline)
                            Text("Start the conversation by sending the first message")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxHeight: .infinity)
                        .padding()
                    } else {
                        ScrollViewReader { scrollProxy in
                            List {
                                ForEach(messages) { message in
                                    ConversationMessageRow(message: message, conversationEncryptionKey: conversation.encryptionKey, deviceId: deviceId)
                                        .id(message.id)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                }
                            }
                            .onChange(of: messages.count) { _ in
                                if let lastMessage = messages.last {
                                    withAnimation {
                                        scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // Message Input
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            TextField("Type a message...", text: $messageText, axis: .vertical)
                                .lineLimit(5)
                                .focused($messageFieldFocused)
                                .textFieldStyle(.roundedBorder)

                            Button(action: {
                                Task {
                                    await sendMessage()
                                }
                            }) {
                                if isSending {
                                    ProgressView()
                                        .tint(.indigo)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.indigo)
                                }
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending || conversation.isExpired)
                        }

                        HStack {
                            Button(action: generateShareLink) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Conversation")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.indigo)
                        }
                    }
                    .padding()
                }

                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
            .sheet(isPresented: $showShareModal) {
                ConversationShareView(shareLink: $shareLink, conversationId: conversation.id)
            }
            .onAppear {
                Task {
                    await loadMessages()
                }
                startPolling()
            }
            .onDisappear {
                stopPolling()
            }
            .refreshable {
                await loadMessages()
            }
            .background(Color(.systemBackground))
        }
    }

    @MainActor
    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            print("[DEBUG] ConversationDetailView - Starting loadMessages for conversationId: \(conversation.id)")

            // Retrieve encryption key from storage
            if let storedKey = KeyStore.shared.retrieveKey(for: conversation.id) {
                print("[DEBUG] ConversationDetailView - Found stored encryption key for conversation")
                conversation.encryptionKey = storedKey
            } else {
                print("[WARNING] ConversationDetailView - No stored encryption key found for conversation")
            }

            messages = try await apiService.getConversationMessages(conversationId: conversation.id)
            print("[DEBUG] ConversationDetailView - Loaded \(messages.count) messages")

            // Track the timestamp of the most recent message for incremental polling
            if let lastMessage = messages.last {
                lastMessageTimestamp = lastMessage.createdAt
                print("[DEBUG] ConversationDetailView - Last message timestamp: \(String(describing: lastMessage.createdAt))")
            } else {
                // No messages yet, use current time
                lastMessageTimestamp = Date()
                print("[DEBUG] ConversationDetailView - No messages, using current time as baseline")
            }

            errorMessage = nil
        } catch let error as NetworkError {
            print("[ERROR] ConversationDetailView - NetworkError: \(error)")
            errorMessage = error.localizedDescription
        } catch {
            print("[ERROR] ConversationDetailView - Failed to load messages: \(error)")
            errorMessage = "Failed to load messages"
        }
    }

    private func startPolling() {
        print("[DEBUG] ConversationDetailView - Starting polling for conversation: \(conversation.id)")

        // Stop any existing timer first
        stopPolling()

        // Start polling timer (lastMessageTimestamp already set by loadMessages)
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            Task {
                await pollForNewMessages()
            }
        }
    }

    private func stopPolling() {
        if pollTimer != nil {
            print("[DEBUG] ConversationDetailView - Stopping polling for conversation: \(conversation.id)")
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }

    @MainActor
    private func pollForNewMessages() async {
        guard let lastTimestamp = lastMessageTimestamp else {
            print("[DEBUG] ConversationDetailView - No lastMessageTimestamp, skipping poll")
            return
        }

        do {
            print("[DEBUG] ConversationDetailView - Polling for new messages since: \(lastTimestamp)")

            // Fetch only messages created after the last message we have
            let newMessages = try await apiService.getConversationMessagesSince(
                conversationId: conversation.id,
                since: lastTimestamp
            )

            if !newMessages.isEmpty {
                print("[DEBUG] ConversationDetailView - Received \(newMessages.count) new messages")

                // Filter out messages that already exist (by ID) to prevent duplicates
                let existingIds = Set(messages.map { $0.id })
                let uniqueNewMessages = newMessages.filter { !existingIds.contains($0.id) }

                if !uniqueNewMessages.isEmpty {
                    print("[DEBUG] ConversationDetailView - Adding \(uniqueNewMessages.count) unique new messages (filtered \(newMessages.count - uniqueNewMessages.count) duplicates)")
                    // Add only unique new messages to the list
                    messages.append(contentsOf: uniqueNewMessages)
                } else {
                    print("[DEBUG] ConversationDetailView - All \(newMessages.count) messages were duplicates, skipping")
                }

                // Update timestamp to the most recent message (whether unique or not)
                if let lastMessage = newMessages.last {
                    lastMessageTimestamp = lastMessage.createdAt
                    print("[DEBUG] ConversationDetailView - Updated last message timestamp: \(String(describing: lastMessage.createdAt))")
                }
            } else {
                print("[DEBUG] ConversationDetailView - No new messages in this poll")
            }

            // Also check if other participants are still active (detect when initiator deletes)
            // This is a secondary check - the primary detection happens via 404 on conversation fetch
            print("[DEBUG] ConversationDetailView - Checking if conversation is still active")
            _ = try await apiService.getConversation(id: conversation.id)

        } catch let error as NetworkError {
            if case .conversationNotFound = error {
                print("[ERROR] ConversationDetailView - Conversation no longer exists (deleted or expired)")
                // Conversation was deleted - clean up locally
                stopPolling()
                await MainActor.run {
                    ConversationLinkStore.shared.deleteLink(for: conversation.id)
                    KeyStore.shared.deleteKey(for: conversation.id)
                    errorMessage = "This conversation has been deleted"
                }
            } else {
                print("[ERROR] ConversationDetailView - Polling error: \(error)")
                // Don't show other polling errors to user - silently continue polling
            }
        } catch {
            print("[ERROR] ConversationDetailView - Unexpected polling error: \(error)")
            // Don't show polling errors to user - silently continue polling
        }
    }

    @MainActor
    private func sendMessage() async {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespaces)
        print("[DEBUG] sendMessage - Message text: '\(trimmedMessage)'")
        guard !trimmedMessage.isEmpty else {
            print("[DEBUG] sendMessage - Message is empty, returning")
            return
        }
        guard !conversation.isExpired else {
            print("[DEBUG] sendMessage - Conversation is expired")
            errorMessage = "This conversation has expired"
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            // Use conversation's master encryption key if available
            let keyString: String
            let key: SymmetricKey

            if let conversationKey = conversation.encryptionKey {
                print("[DEBUG] sendMessage - Using conversation's master encryption key")
                keyString = conversationKey
                key = try CryptoManager.keyFromBase64String(conversationKey)
            } else {
                print("[DEBUG] sendMessage - Generating new encryption key for conversation")
                key = CryptoManager.generateKey()
                keyString = CryptoManager.keyToBase64String(key)
            }

            print("[DEBUG] sendMessage - Encrypting message")
            let encryptedMessage = try CryptoManager.encrypt(message: trimmedMessage, key: key)
            print("[DEBUG] sendMessage - Encrypted message: ciphertext length=\(encryptedMessage.ciphertext.count), nonce=\(encryptedMessage.nonce), tag=\(encryptedMessage.tag)")

            print("[DEBUG] sendMessage - Sending to backend, conversationId=\(conversation.id), deviceId=\(deviceId)")
            var newMessage = try await apiService.addConversationMessage(
                conversationId: conversation.id,
                encryptedMessage: encryptedMessage,
                deviceId: deviceId
            )

            print("[DEBUG] sendMessage - Message sent successfully, id=\(newMessage.id)")

            // Store the encryption key so we can decrypt our own message
            newMessage.encryptionKey = keyString
            newMessage.decryptedContent = trimmedMessage

            messages.append(newMessage)

            // Update polling timestamp to the newly sent message's timestamp
            if let createdAt = newMessage.createdAt {
                lastMessageTimestamp = createdAt
                print("[DEBUG] sendMessage - Updated lastMessageTimestamp to newly sent message: \(createdAt)")
            }

            messageText = ""
            messageFieldFocused = false
            errorMessage = nil
            onUpdate()
        } catch let error as NetworkError {
            print("[ERROR] sendMessage - NetworkError: \(error)")
            errorMessage = error.localizedDescription
        } catch {
            print("[ERROR] sendMessage - Unexpected error: \(error)")
            errorMessage = "Failed to send message: \(error)"
        }
    }

    private func generateShareLink() {
        print("[DEBUG] ConversationDetailView - generateShareLink called")
        Task {
            do {
                print("[DEBUG] ConversationDetailView - Calling apiService.generateConversationShareLink")
                let baseLink = try await apiService.generateConversationShareLink(
                    conversationId: conversation.id,
                    deviceId: deviceId
                )

                // Append encryption key to the link fragment
                var fullLink = baseLink
                if let encryptionKey = conversation.encryptionKey {
                    print("[DEBUG] ConversationDetailView - Appending encryption key to share link")
                    fullLink = baseLink + "#" + encryptionKey
                } else {
                    print("[WARNING] ConversationDetailView - No encryption key available for conversation")
                }

                print("[DEBUG] ConversationDetailView - Share link generated: \(fullLink)")
                await MainActor.run {
                    print("[DEBUG] ConversationDetailView - Updating shareLink and showShareModal on MainActor")
                    self.shareLink = fullLink
                    print("[DEBUG] ConversationDetailView - shareLink set to: \(self.shareLink)")
                    self.showShareModal = true
                    print("[DEBUG] ConversationDetailView - showShareModal is now: \(self.showShareModal)")
                }
            } catch let error as NetworkError {
                print("[ERROR] ConversationDetailView - NetworkError: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            } catch {
                print("[ERROR] ConversationDetailView - Unexpected error: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to generate share link"
                }
            }
        }
    }
}

struct ConversationMessageRow: View {
    let message: ConversationMessage
    let conversationEncryptionKey: String?
    let deviceId: String
    @State private var decryptedText: String?

    var isSentByCurrentDevice: Bool {
        message.senderDeviceId == deviceId
    }

    var body: some View {
        HStack(spacing: 8) {
            if isSentByCurrentDevice {
                // Sent message - right-aligned
                Spacer()
                messageBubble
                    .foregroundColor(.white)
            } else {
                // Received message - left-aligned
                messageBubble
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onAppear {
            // Try to decrypt on appearance if we have the key
            if let ciphertext = message.ciphertext, let nonce = message.nonce, let tag = message.tag {
                let keyToUse = message.encryptionKey ?? conversationEncryptionKey
                if let keyString = keyToUse {
                    decryptedText = attemptDecryption(ciphertext: ciphertext, nonce: nonce, tag: tag, keyString: keyString)
                }
            }
        }
    }

    private var messageBubble: some View {
        VStack(alignment: isSentByCurrentDevice ? .trailing : .leading, spacing: 4) {
            // Message content bubble
            if let decryptedContent = decryptedText ?? message.decryptedContent {
                Text(decryptedContent)
                    .padding(12)
                    .background(isSentByCurrentDevice ? Color.blue : Color.gray.opacity(0.2))
                    .cornerRadius(16)
            } else if let ciphertext = message.ciphertext, let nonce = message.nonce, let tag = message.tag {
                let keyToUse = message.encryptionKey ?? conversationEncryptionKey
                if let keyString = keyToUse {
                    if let decrypted = attemptDecryption(ciphertext: ciphertext, nonce: nonce, tag: tag, keyString: keyString) {
                        Text(decrypted)
                            .padding(12)
                            .background(isSentByCurrentDevice ? Color.blue : Color.gray.opacity(0.2))
                            .cornerRadius(16)
                    } else {
                        Text("[Unable to decrypt]")
                            .padding(12)
                            .background(isSentByCurrentDevice ? Color.blue : Color.gray.opacity(0.2))
                            .cornerRadius(16)
                            .italic()
                    }
                } else {
                    Text("[Encrypted Message]")
                        .padding(12)
                        .background(isSentByCurrentDevice ? Color.blue : Color.gray.opacity(0.2))
                        .cornerRadius(16)
                        .italic()
                }
            } else {
                Text("[Encrypted Message]")
                    .padding(12)
                    .background(isSentByCurrentDevice ? Color.blue : Color.gray.opacity(0.2))
                    .cornerRadius(16)
                    .italic()
            }

            // Time and status row
            HStack(spacing: 4) {
                if let createdAt = message.createdAt {
                    Text(createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                // Status indicators for sent messages only
                if isSentByCurrentDevice {
                    if message.readAt != nil {
                        // Double blue check for read
                        HStack(spacing: -2) {
                            Text("✓")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("✓")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Single check for delivered
                        Text("✓")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    private func attemptDecryption(ciphertext: String, nonce: String, tag: String, keyString: String) -> String? {
        do {
            let key = try CryptoManager.keyFromBase64String(keyString)
            let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, nonce: nonce, tag: tag)
            let decrypted = try CryptoManager.decrypt(encryptedMessage: encryptedMessage, key: key)
            return decrypted
        } catch {
            print("[DEBUG] ConversationMessageRow - Failed to decrypt message: \(error)")
            return nil
        }
    }
}

#Preview {
    let conversation = Conversation(
        id: UUID(),
        initiatorUserId: UUID(),
        status: "ACTIVE",
        createdAt: Date(),
        expiresAt: Date(timeIntervalSinceNow: 3600)
    )
    ConversationDetailView(conversation: conversation, deviceId: "preview", onUpdate: {})
}
