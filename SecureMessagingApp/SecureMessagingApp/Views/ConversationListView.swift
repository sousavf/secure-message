import SwiftUI

struct ConversationListView: View {
    @StateObject private var apiService = APIService.shared
    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedConversation: Conversation?
    @State private var showCreateConversation = false
    @State private var showQRScanner = false
    @FocusState private var focusedField: String?

    var deviceId: String

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if conversations.isEmpty && !isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "bubble.right.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.indigo)
                            Text("No Conversations")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Start a new conversation or accept an invitation from a friend")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                    } else {
                        List {
                            ForEach(conversations) { conversation in
                                NavigationLink(destination: ConversationDetailView(conversation: conversation, deviceId: deviceId, onUpdate: {
                                    Task {
                                        await loadConversations()
                                    }
                                })) {
                                    ConversationRowView(conversation: conversation)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                Task {
                                                    await deleteConversation(conversation.id)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Conversations")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showQRScanner = true }) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title3)
                                .foregroundColor(.indigo)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showCreateConversation = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.indigo)
                        }
                    }
                }
                .sheet(isPresented: $showCreateConversation) {
                    CreateConversationView(deviceId: deviceId) { newConversation in
                        conversations.insert(newConversation, at: 0)
                        showCreateConversation = false
                    }
                }
                .sheet(isPresented: $showQRScanner) {
                    QRScannerView { scannedCode in
                        handleQRCodeScanned(scannedCode)
                    }
                }
                .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                    Button("OK") { errorMessage = nil }
                }, message: {
                    Text(errorMessage ?? "")
                })

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
            .onAppear {
                Task {
                    await loadConversations()
                }
            }
            .refreshable {
                await loadConversations()
            }
        }
    }

    @MainActor
    private func loadConversations() async {
        isLoading = true
        defer { isLoading = false }

        do {
            print("[DEBUG] ConversationListView - Starting listConversations with deviceId: \(deviceId)")
            conversations = try await apiService.listConversations(deviceId: deviceId)

            // Load stored encryption keys for each conversation
            for i in 0..<conversations.count {
                if let storedKey = KeyStore.shared.retrieveKey(for: conversations[i].id) {
                    print("[DEBUG] ConversationListView - Loaded stored key for conversation: \(conversations[i].id)")
                    conversations[i].encryptionKey = storedKey
                }
            }

            // Also load joined conversations from local storage
            print("[DEBUG] ConversationListView - Loading joined conversations from local storage")
            let joinedConversationIds = ConversationLinkStore.shared.getAllConversationIds()
            for joinedId in joinedConversationIds {
                // Skip if already in list (created by this device)
                if conversations.contains(where: { $0.id == joinedId }) {
                    continue
                }

                // Fetch joined conversation from backend
                do {
                    let joinedConversation = try await apiService.getConversation(id: joinedId)
                    var updatedConversation = joinedConversation

                    // Load encryption key
                    if let storedKey = KeyStore.shared.retrieveKey(for: joinedId) {
                        updatedConversation.encryptionKey = storedKey
                    }

                    conversations.append(updatedConversation)
                    print("[DEBUG] ConversationListView - Loaded joined conversation: \(joinedId)")
                } catch {
                    print("[WARNING] ConversationListView - Failed to load joined conversation \(joinedId): \(error)")
                    // Remove expired link if conversation no longer exists
                    ConversationLinkStore.shared.deleteLink(for: joinedId)
                }
            }

            print("[DEBUG] ConversationListView - Loaded \(conversations.count) conversations total")
            errorMessage = nil
        } catch let error as NetworkError {
            print("[ERROR] ConversationListView - NetworkError caught: \(error)")
            errorMessage = error.localizedDescription
        } catch {
            print("[ERROR] ConversationListView - Unexpected error caught: \(error)")
            print("[ERROR] ConversationListView - Error type: \(type(of: error))")
            errorMessage = "Failed to load conversations: \(error)"
        }
    }

    private func handleQRCodeScanned(_ code: String) {
        print("[DEBUG] ConversationListView - QR code scanned: \(code)")

        // Close the QR scanner sheet
        showQRScanner = false

        // Parse the conversation link to extract conversation ID and encryption key
        // Expected format: https://privileged.stratholme.eu/join/4c80ec7f-996e-4249-9b9b-9377c6abcdf8#BASE64_ENCRYPTION_KEY
        if let url = URL(string: code),
           let lastComponent = url.pathComponents.last,
           let conversationId = UUID(uuidString: lastComponent) {
            print("[DEBUG] ConversationListView - Extracted conversation ID: \(conversationId)")

            // Extract encryption key from URL fragment
            let encryptionKey = url.fragment
            if let key = encryptionKey, !key.isEmpty {
                print("[DEBUG] ConversationListView - Found encryption key in QR code, storing it")
                KeyStore.shared.storeKey(key, for: conversationId)
            }

            // Save the conversation link locally
            print("[DEBUG] ConversationListView - Saving conversation link locally")
            ConversationLinkStore.shared.saveLink(conversationId, link: code)

            // Check if we already have this conversation
            if let existingConversation = conversations.first(where: { $0.id == conversationId }) {
                print("[DEBUG] ConversationListView - Conversation already in list, navigating to it")
                selectedConversation = existingConversation
            } else {
                print("[DEBUG] ConversationListView - Conversation not in list, fetching from backend")
                // Fetch the conversation from the backend and register as participant
                Task {
                    do {
                        print("[DEBUG] ConversationListView - Fetching conversation from backend: \(conversationId)")
                        let conversation = try await apiService.getConversation(id: conversationId)

                        // Register this device as a participant
                        print("[DEBUG] ConversationListView - Registering device as participant")
                        try await apiService.joinConversation(conversationId: conversationId, deviceId: deviceId)

                        await MainActor.run {
                            print("[DEBUG] ConversationListView - Conversation fetched and joined successfully")
                            // Add to conversations list
                            var updatedConversation = conversation
                            if let key = encryptionKey, !key.isEmpty {
                                updatedConversation.encryptionKey = key
                            }
                            conversations.insert(updatedConversation, at: 0)
                            selectedConversation = updatedConversation
                        }
                    } catch let error as NetworkError {
                        print("[ERROR] ConversationListView - Failed to fetch conversation or join: \(error)")
                        await MainActor.run {
                            if case .linkAlreadyConsumed(let message) = error {
                                errorMessage = message
                            } else {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } catch {
                        print("[ERROR] ConversationListView - Failed to fetch conversation or join: \(error)")
                        await MainActor.run {
                            errorMessage = "Failed to join conversation. Please try again."
                        }
                    }
                }
            }
        } else {
            print("[ERROR] ConversationListView - Failed to parse QR code: \(code)")
            errorMessage = "Invalid QR code format"
        }
    }

    @MainActor
    private func deleteConversation(_ id: UUID) async {
        do {
            try await apiService.deleteConversation(id: id, deviceId: deviceId)
            conversations.removeAll { $0.id == id }

            // Also remove from local storage
            ConversationLinkStore.shared.deleteLink(for: id)
            KeyStore.shared.deleteKey(for: id)

            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to delete conversation"
        }
    }
}

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private Conversation")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Created \(conversation.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if conversation.isExpired {
                        Text("Expired")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    } else {
                        Text(conversation.timeRemaining)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.indigo)
                    }
                    Text("Expires \(conversation.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationListView(deviceId: "preview-device-id")
}
