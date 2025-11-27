import SwiftUI
import CryptoKit

struct ConversationListView: View {
    @StateObject private var apiService = APIService.shared
    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedConversation: Conversation?
    @State private var showCreateConversation = false
    @State private var showQRScanner = false
    @State private var showNameEditor = false
    @State private var editingConversationId: UUID?
    @State private var editingName: String = ""
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
                        ScrollView {
                            LazyVStack(spacing: 1) {
                                ForEach(conversations) { conversation in
                                    NavigationLink(destination: ConversationDetailView(conversation: conversation, deviceId: deviceId, onUpdate: {
                                        Task {
                                            await loadConversations()
                                        }
                                    })) {
                                        ConversationRowView(conversation: conversation, onEditName: {
                                            openNameEditor(for: conversation)
                                        })
                                        .background(Color(.systemBackground))
                                    }
                                    .contextMenu {
                                        Button(role: conversation.isCreatedByCurrentDevice ? .destructive : nil) {
                                            Task {
                                                if conversation.isCreatedByCurrentDevice {
                                                    await deleteConversation(conversation.id)
                                                } else {
                                                    await leaveConversation(conversation.id)
                                                }
                                            }
                                        } label: {
                                            if conversation.isCreatedByCurrentDevice {
                                                Label("Delete", systemImage: "trash")
                                            } else {
                                                Label("Leave", systemImage: "person.slash.fill")
                                            }
                                        }

                                        Button {
                                            openNameEditor(for: conversation)
                                        } label: {
                                            Label("Edit Name", systemImage: "pencil")
                                        }
                                    }

                                    Divider()
                                        .padding(.leading, 68)
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
                .sheet(isPresented: $showNameEditor) {
                    if let conversationId = editingConversationId {
                        VStack(spacing: 16) {
                            Text("Edit Conversation Name")
                                .font(.headline)

                            TextField("Conversation name", text: $editingName)
                                .textFieldStyle(.roundedBorder)
                                .padding()

                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    showNameEditor = false
                                    editingConversationId = nil
                                    editingName = ""
                                }
                                .frame(maxWidth: .infinity)

                                Button("Save") {
                                    saveConversationName(for: conversationId)
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                        }
                        .padding()
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
                // Use a detached task to avoid cancellation issues with refreshable modifier
                await Task.detached(priority: .userInitiated) {
                    await loadConversations()
                }.value
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleConversationDeepLink"))) { notification in
                // Handle conversation deep link (when user follows a shared link)
                if let url = notification.object as? URL {
                    print("[DEBUG] ConversationListView - Received conversation deep link: \(url.absoluteString)")
                    handleQRCodeScanned(url.absoluteString)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PushNotificationConversationTapped"))) { notification in
                // Handle push notification tap (user tapped a notification)
                if let conversationHash = notification.object as? String {
                    print("[DEBUG] ConversationListView - User tapped notification for conversation hash: \(conversationHash)")
                    handlePushNotificationTap(conversationHash: conversationHash)
                }
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

            // Load stored encryption keys and custom names for each conversation
            for i in 0..<conversations.count {
                if let storedKey = KeyStore.shared.retrieveKey(for: conversations[i].id) {
                    print("[DEBUG] ConversationListView - Loaded stored key for conversation: \(conversations[i].id)")
                    conversations[i].encryptionKey = storedKey
                }
                if let customName = ConversationNameStore.shared.retrieveName(for: conversations[i].id) {
                    print("[DEBUG] ConversationListView - Loaded custom name '\(customName)' for conversation: \(conversations[i].id)")
                    conversations[i].localName = customName
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
                    updatedConversation.isCreatedByCurrentDevice = false // Mark as joined, not created

                    // Load encryption key and custom name
                    if let storedKey = KeyStore.shared.retrieveKey(for: joinedId) {
                        updatedConversation.encryptionKey = storedKey
                    }
                    if let customName = ConversationNameStore.shared.retrieveName(for: joinedId) {
                        updatedConversation.localName = customName
                    }

                    conversations.append(updatedConversation)
                    print("[DEBUG] ConversationListView - Loaded joined conversation: \(joinedId)")
                } catch {
                    print("[WARNING] ConversationListView - Failed to load joined conversation \(joinedId): \(error)")
                    // Remove expired link if conversation no longer exists (e.g., deleted by initiator)
                    ConversationLinkStore.shared.deleteLink(for: joinedId)
                    KeyStore.shared.deleteKey(for: joinedId)
                    print("[DEBUG] ConversationListView - Cleaned up local storage for deleted conversation: \(joinedId)")
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
                            updatedConversation.isCreatedByCurrentDevice = false // Mark as joined, not created
                            if let key = encryptionKey, !key.isEmpty {
                                updatedConversation.encryptionKey = key
                            }
                            // Load custom name if exists
                            if let customName = ConversationNameStore.shared.retrieveName(for: conversationId) {
                                updatedConversation.localName = customName
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
    private func handlePushNotificationTap(conversationHash: String) {
        print("[DEBUG] ConversationListView - Finding conversation for hash: \(conversationHash)")

        // Find the conversation that matches this hash
        for conversation in conversations {
            let currentConversationHash = hashConversationId(conversation.id)
            if currentConversationHash == conversationHash {
                print("[DEBUG] ConversationListView - Found matching conversation: \(conversation.id)")
                selectedConversation = conversation
                return
            }
        }

        print("[WARNING] ConversationListView - No conversation found matching hash: \(conversationHash)")
        // Conversation not found in current list, try reloading conversations
        Task {
            print("[DEBUG] ConversationListView - Reloading conversations to find notification conversation")
            await loadConversations()

            // Try again after reload
            for conversation in conversations {
                let currentConversationHash = hashConversationId(conversation.id)
                if currentConversationHash == conversationHash {
                    print("[DEBUG] ConversationListView - Found matching conversation after reload: \(conversation.id)")
                    await MainActor.run {
                        selectedConversation = conversation
                    }
                    return
                }
            }

            print("[ERROR] ConversationListView - Still couldn't find conversation for hash: \(conversationHash)")
            await MainActor.run {
                errorMessage = "Could not find conversation from notification"
            }
        }
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

    @MainActor
    private func leaveConversation(_ id: UUID) async {
        do {
            try await apiService.leaveConversation(id: id, deviceId: deviceId)
            conversations.removeAll { $0.id == id }

            // Remove from local storage
            ConversationLinkStore.shared.deleteLink(for: id)
            KeyStore.shared.deleteKey(for: id)

            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to leave conversation"
        }
    }

    private func saveConversationName(for conversationId: UUID) {
        let trimmedName = editingName.trimmingCharacters(in: .whitespaces)
        print("[DEBUG] ConversationListView - Saving name '\(trimmedName)' for conversation: \(conversationId)")

        // Store the name (empty names will clear the stored name)
        ConversationNameStore.shared.storeName(trimmedName, for: conversationId)

        // Update the conversation in memory
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].localName = trimmedName.isEmpty ? nil : trimmedName
            print("[DEBUG] ConversationListView - Updated conversation name in memory")
        }

        // Close the editor
        showNameEditor = false
        editingConversationId = nil
        editingName = ""
    }

    private func openNameEditor(for conversation: Conversation) {
        editingConversationId = conversation.id
        editingName = conversation.localName ?? ""
        showNameEditor = true
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    var onEditName: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with initials
            ZStack {
                Circle()
                    .fill(avatarColor)

                Text(avatarInitials)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)

            // Main content
            VStack(alignment: .leading, spacing: 6) {
                // Title row with name and edit button
                HStack(spacing: 8) {
                    let displayName = conversation.localName ?? "Private Conversation"
                    Text(displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)

                    Button(action: onEditName) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.indigo)
                            .opacity(0.6)
                    }

                    Spacer()
                }

                // Subtitle with status and time
                HStack(spacing: 8) {
                    if conversation.isExpired {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Expired")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.red)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                            Text(conversation.timeRemaining)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.indigo)
                    }

                    Spacer()

                    // Time badge
                    Text(formatTime(conversation.createdAt))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var avatarInitials: String {
        let displayName = conversation.localName ?? "Private Conversation"
        let components = displayName.split(separator: " ")

        if components.count >= 2 {
            let first = components[0].prefix(1).uppercased()
            let second = components[1].prefix(1).uppercased()
            return first + second
        } else {
            return displayName.prefix(2).uppercased()
        }
    }

    private var avatarColor: Color {
        let displayName = conversation.localName ?? "Private Conversation"
        let colors: [Color] = [
            .blue,
            Color(red: 0.4, green: 0.2, blue: 0.8), // Indigo/Purple
            Color(red: 0.2, green: 0.6, blue: 0.8), // Cyan
            Color(red: 0.8, green: 0.2, blue: 0.4), // Pink
            Color(red: 0.2, green: 0.8, blue: 0.4), // Green
            Color(red: 0.8, green: 0.6, blue: 0.2), // Orange
        ]

        let hash = displayName.hashValue
        let index = abs(hash) % colors.count
        return colors[index]
    }

    private func formatTime(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: date, to: now)
            if let days = components.day, days < 7 {
                return "\(days)d ago"
            } else {
                return date.formatted(date: .abbreviated, time: .omitted)
            }
        }
    }
}

#Preview {
    ConversationListView(deviceId: "preview-device-id")
}
