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
    @State private var showNameEditor = false
    @State private var editingName: String = ""
    @FocusState private var messageFieldFocused: Bool

    // Push notification state
    @State private var pushNotificationsEnabled = false

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
                        .onTapGesture {
                            messageFieldFocused = false
                        }
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
                            .onTapGesture {
                                messageFieldFocused = false
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
                                .font(.system(size: 18, weight: .regular))
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(20)
                                .frame(minHeight: 44)

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
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.indigo)
                            .cornerRadius(25)
                            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending || conversation.isExpired)
                        }

                        // Only show share button for conversation creator if no one has joined yet
                        let hasOtherDeviceParticipant = messages.contains { message in
                            message.senderDeviceId != deviceId
                        }

                        if conversation.isCreatedByCurrentDevice && !hasOtherDeviceParticipant {
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
                    }
                    .padding()
                }

                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle(conversation.localName ?? "Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingName = conversation.localName ?? ""
                        showNameEditor = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.indigo)
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
            .sheet(isPresented: $showNameEditor) {
                VStack(spacing: 16) {
                    Text("Edit Conversation Name")
                        .font(.headline)

                    TextField("Conversation name", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .padding()

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showNameEditor = false
                            editingName = ""
                        }
                        .frame(maxWidth: .infinity)

                        Button("Save") {
                            saveConversationName()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                .padding()
            }
            .sheet(isPresented: $showShareModal) {
                ConversationShareView(shareLink: $shareLink, conversationId: conversation.id)
            }
            .onAppear {
                Task {
                    await loadMessages()
                    pushNotificationsEnabled = await PushNotificationService.shared.isNotificationEnabled()
                }
                setupPushNotificationListener()
            }
            .onDisappear {
                removePushNotificationListener()
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

            errorMessage = nil
        } catch let error as NetworkError {
            print("[ERROR] ConversationDetailView - NetworkError: \(error)")
            errorMessage = error.localizedDescription
        } catch {
            print("[ERROR] ConversationDetailView - Failed to load messages: \(error)")
            errorMessage = "Failed to load messages"
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

            messageText = ""
            // Keep keyboard focused instead of dismissing it
            messageFieldFocused = true
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

    private func saveConversationName() {
        let trimmedName = editingName.trimmingCharacters(in: .whitespaces)
        print("[DEBUG] ConversationDetailView - Saving name '\(trimmedName)' for conversation: \(conversation.id)")

        // Store the name (empty names will clear the stored name)
        ConversationNameStore.shared.storeName(trimmedName, for: conversation.id)

        // Update the conversation in memory
        conversation.localName = trimmedName.isEmpty ? nil : trimmedName
        print("[DEBUG] ConversationDetailView - Updated conversation name in memory")

        // Close the editor
        showNameEditor = false
        editingName = ""
    }

    // MARK: - Push Notification Integration

    private func setupPushNotificationListener() {
        print("[DEBUG] ConversationDetailView - Setting up push notification listener for conversation: \(conversation.id)")

        let currentConversationHash = hashConversationId(conversation.id)

        NotificationCenter.default.addObserver(
            forName: PushNotificationService.newMessageReceivedNotification,
            object: nil,
            queue: .main
        ) { notification in
            // Check if this push is for our conversation
            if let userInfo = notification.userInfo,
               let conversationHash = userInfo["conversationHash"] as? String {

                if conversationHash == currentConversationHash {
                    // Check the notification type
                    if let notificationType = userInfo["type"] as? String {
                        print("[DEBUG] ConversationDetailView - Push notification received, type: \(notificationType)")

                        switch notificationType {
                        case "deleted":
                            print("[DEBUG] ConversationDetailView - Conversation was deleted")
                            Task {
                                await self.handleConversationDeleted()
                            }
                        case "expired":
                            print("[DEBUG] ConversationDetailView - Conversation expired")
                            Task {
                                await self.handleConversationExpired()
                            }
                        default:
                            print("[DEBUG] ConversationDetailView - New message received, fetching new messages")
                            Task {
                                await self.loadMessages()
                            }
                        }
                    } else {
                        print("[DEBUG] ConversationDetailView - Push notification received (regular message), fetching new messages")
                        // Reload messages when push arrives for this conversation
                        Task {
                            await self.loadMessages()
                        }
                    }
                } else {
                    print("[DEBUG] ConversationDetailView - Push notification received for different conversation (hash: \(conversationHash)), ignoring")
                }
            }
        }
    }

    @MainActor
    private func handleConversationDeleted() async {
        print("[DEBUG] ConversationDetailView - Handling conversation deletion")

        // Delete from local storage
        ConversationLinkStore.shared.deleteLink(for: conversation.id)
        KeyStore.shared.deleteKey(for: conversation.id)

        // Show toast with error message
        errorMessage = "Conversation has been deleted"

        // Navigation will be handled by ConversationListView when it detects the conversation is missing
        // For now, just trigger the onUpdate callback which will refresh the list
        onUpdate()
    }

    @MainActor
    private func handleConversationExpired() async {
        print("[DEBUG] ConversationDetailView - Handling conversation expiration")

        // Delete from local storage
        ConversationLinkStore.shared.deleteLink(for: conversation.id)
        KeyStore.shared.deleteKey(for: conversation.id)

        // Show toast with error message
        errorMessage = "Conversation has expired"

        // Navigation will be handled by ConversationListView when it detects the conversation is missing
        // For now, just trigger the onUpdate callback which will refresh the list
        onUpdate()
    }

    private func removePushNotificationListener() {
        print("[DEBUG] ConversationDetailView - Removing push notification listener")
        NotificationCenter.default.removeObserver(self, name: PushNotificationService.newMessageReceivedNotification, object: nil)
    }

    /// Hash conversation ID to match backend implementation
    /// Must use lowercase UUID string to match Java's UUID.toString() format
    private func hashConversationId(_ id: UUID) -> String {
        let lowercaseUUID = id.uuidString.lowercased()
        let data = lowercaseUUID.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return String(hashString.prefix(32))
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
