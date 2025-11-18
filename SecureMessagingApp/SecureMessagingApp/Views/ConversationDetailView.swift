import SwiftUI

struct ConversationDetailView: View {
    var conversation: Conversation
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
                                    ConversationMessageRow(message: message)
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
                ConversationShareView(shareLink: shareLink, conversationId: conversation.id)
            }
            .onAppear {
                Task {
                    await loadMessages()
                }
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
            print("[DEBUG] sendMessage - Generating encryption key")
            let key = CryptoManager.generateKey()
            let keyString = CryptoManager.keyToBase64String(key)

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
                let link = try await apiService.generateConversationShareLink(
                    conversationId: conversation.id,
                    deviceId: deviceId
                )
                print("[DEBUG] ConversationDetailView - Share link received: \(link)")
                await MainActor.run {
                    print("[DEBUG] ConversationDetailView - Updating shareLink and showShareModal on MainActor")
                    self.shareLink = link
                    print("[DEBUG] ConversationDetailView - shareLink set to: \(self.shareLink ?? "nil")")
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
    @State private var decryptedText: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let decryptedContent = decryptedText ?? message.decryptedContent {
                    // Display decrypted message
                    Text(decryptedContent)
                        .padding(12)
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                } else if let ciphertext = message.ciphertext, let nonce = message.nonce, let tag = message.tag, let keyString = message.encryptionKey {
                    // Try to decrypt if we have the key
                    Text(attemptDecryption(ciphertext: ciphertext, nonce: nonce, tag: tag, keyString: keyString) ?? "[Encrypted Message]")
                        .padding(12)
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                } else {
                    // Can't decrypt - show placeholder
                    Text("[Encrypted Message]")
                        .padding(12)
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(12)
                        .italic()
                        .foregroundColor(.secondary)
                }

                if let createdAt = message.createdAt {
                    Text(createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .onAppear {
            // Try to decrypt on appearance if we have the key
            if let ciphertext = message.ciphertext, let nonce = message.nonce, let tag = message.tag, let keyString = message.encryptionKey {
                decryptedText = attemptDecryption(ciphertext: ciphertext, nonce: nonce, tag: tag, keyString: keyString)
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
