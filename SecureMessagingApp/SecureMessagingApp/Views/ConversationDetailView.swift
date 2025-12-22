import SwiftUI
import CryptoKit
import PhotosUI
import UIKit

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

    // File sharing state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotosPicker: Bool = false
    @State private var showFilePicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var selectedFileData: Data?
    @State private var selectedFileName: String?
    @State private var isUploadingFile: Bool = false

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
                                ForEach(messages, id: \.id) { message in
                                    ConversationMessageRow(message: message, conversationEncryptionKey: conversation.encryptionKey, deviceId: deviceId)
                                        .id(message.id)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
                                        .listRowBackground(Color.clear)
                                }
                            }
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemBackground))
                            .onTapGesture {
                                messageFieldFocused = false
                            }
                            .onChange(of: messages.count) { _ in
                                // Delay scroll to ensure layout is complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let lastMessage = messages.last {
                                        withAnimation {
                                            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                            .onAppear {
                                // Scroll to bottom when view appears
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let lastMessage = messages.last {
                                        scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // Message Input
                    VStack(spacing: 12) {
                        // File preview if selected
                        if let fileName = selectedFileName {
                            HStack(spacing: 12) {
                                Image(systemName: "paperclip.circle.fill")
                                    .foregroundColor(.indigo)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fileName)
                                        .font(.caption)
                                        .lineLimit(1)
                                    if let fileData = selectedFileData {
                                        Text(FileService.shared.formatFileSize(fileData.count))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Button(action: {
                                    selectedFileData = nil
                                    selectedFileName = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }

                        HStack(spacing: 12) {
                            // Attachment button
                            Menu {
                                Button(action: { showPhotosPicker = true }) {
                                    Label("Photo Library", systemImage: "photo.fill")
                                }
                                Button(action: { showCamera = true }) {
                                    Label("Camera", systemImage: "camera.fill")
                                }
                                Button(action: { showFilePicker = true }) {
                                    Label("Files", systemImage: "doc.fill")
                                }
                            } label: {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.indigo)
                                    .cornerRadius(25)
                            }

                            TextField("Type a message...", text: $messageText, axis: .vertical)
                                .lineLimit(5)
                                .focused($messageFieldFocused)
                                .font(.system(size: 16, weight: .regular))
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(20)
                                .frame(minHeight: 44)

                            Button(action: {
                                Task {
                                    if selectedFileData != nil {
                                        await sendFile()
                                    } else {
                                        await sendMessage()
                                    }
                                }
                            }) {
                                if isSending || isUploadingFile {
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
                            .disabled(
                                (messageText.trimmingCharacters(in: .whitespaces).isEmpty && selectedFileData == nil) ||
                                isSending || isUploadingFile || conversation.isExpired
                            )
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
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    await handlePhotoSelection(newValue)
                }
            }
            .sheet(isPresented: $showCamera) {
                ImagePickerView(selectedImage: $selectedFileData, sourceType: .camera) { image in
                    selectedFileName = "photo_\(Date().timeIntervalSince1970).jpg"
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerView { url in
                    handleFileSelection(url)
                }
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

    @MainActor
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

    // MARK: - File Operations

    @MainActor
    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            if let imageData = try await item.loadTransferable(type: Data.self) {
                print("[DEBUG] ConversationDetailView - Processing selected photo")
                let compressedData = try FileService.shared.compressImage(imageData)
                selectedFileData = compressedData
                selectedFileName = "photo_\(Date().timeIntervalSince1970).jpg"
            }
        } catch {
            print("[ERROR] ConversationDetailView - Failed to load photo: \(error)")
            errorMessage = "Failed to load photo: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func handleFileSelection(_ url: URL) {
        print("[DEBUG] ConversationDetailView - Processing selected file: \(url.lastPathComponent)")

        do {
            _ = try url.checkResourceIsReachable()
            let fileData = try Data(contentsOf: url)
            try FileService.shared.validateFileSize(fileData)

            selectedFileData = fileData
            selectedFileName = url.lastPathComponent
        } catch {
            print("[ERROR] ConversationDetailView - Failed to read file: \(error)")
            errorMessage = "Failed to load file: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func sendFile() async {
        guard let fileData = selectedFileData,
              let fileName = selectedFileName,
              let encryptionKey = conversation.encryptionKey else {
            errorMessage = "File or encryption key missing"
            return
        }

        isUploadingFile = true
        defer { isUploadingFile = false }

        do {
            print("[DEBUG] ConversationDetailView - Encrypting and uploading file: \(fileName)")

            // Get encryption key
            let key = try CryptoManager.keyFromBase64String(encryptionKey)

            // Encrypt file
            let encryptedFile = try FileService.shared.encryptFile(fileData, key: key)

            // Get MIME type
            let mimeType = FileService.shared.getMimeType(for: fileName)

            // Upload file
            let uploadResponse = try await apiService.uploadFile(
                conversationId: conversation.id,
                encryptedFile: encryptedFile,
                fileName: fileName,
                fileSize: fileData.count,
                mimeType: mimeType,
                deviceId: deviceId
            )

            print("[DEBUG] ConversationDetailView - File uploaded successfully: \(uploadResponse.fileId)")

            // Reset file selection
            selectedFileData = nil
            selectedFileName = nil
            errorMessage = nil

            // Reload messages to get the file message from server
            await loadMessages()
            onUpdate()
        } catch let error as FileServiceError {
            print("[ERROR] ConversationDetailView - File error: \(error)")
            errorMessage = error.localizedDescription
        } catch {
            print("[ERROR] ConversationDetailView - Failed to send file: \(error)")
            errorMessage = "Failed to send file: \(error.localizedDescription)"
        }
    }
}

struct ConversationMessageRow: View {
    let message: ConversationMessage
    let conversationEncryptionKey: String?
    let deviceId: String
    @State private var decryptedText: String?
    @State private var downloadedFileData: Data?
    @State private var isDownloading: Bool = false
    @State private var downloadError: String?
    @State private var showImageViewer: Bool = false

    var isSentByCurrentDevice: Bool {
        message.senderDeviceId == deviceId
    }

    var body: some View {
        HStack(spacing: 12) {
            if isSentByCurrentDevice {
                Spacer()
            }

            messageBubble
                .frame(maxWidth: 320, alignment: .center)

            if !isSentByCurrentDevice {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 1)
        .onAppear {
            if let ciphertext = message.ciphertext, let nonce = message.nonce, let tag = message.tag {
                let keyToUse = message.encryptionKey ?? conversationEncryptionKey
                if let keyString = keyToUse {
                    decryptedText = attemptDecryption(ciphertext: ciphertext, nonce: nonce, tag: tag, keyString: keyString)
                }
            }
        }
    }

    private var messageBubble: some View {
        VStack(alignment: isSentByCurrentDevice ? .trailing : .leading, spacing: 0.5) {
            // Message content bubble
            if message.messageType == .file || message.messageType == .image {
                // File or image message
                fileMessageContent
            } else if let decryptedContent = decryptedText ?? message.decryptedContent {
                messageText(decryptedContent)
            } else if let ciphertext = message.ciphertext, let nonce = message.nonce, let tag = message.tag {
                let keyToUse = message.encryptionKey ?? conversationEncryptionKey
                if let keyString = keyToUse {
                    if let decrypted = attemptDecryption(ciphertext: ciphertext, nonce: nonce, tag: tag, keyString: keyString) {
                        messageText(decrypted)
                    } else {
                        messageText("[Unable to decrypt]", isError: true)
                    }
                } else {
                    messageText("[Encrypted Message]", isError: true)
                }
            } else {
                messageText("[Encrypted Message]", isError: true)
            }

            // Time and status row - inline with message
            HStack(spacing: 4) {
                Spacer()

                // Always show timestamp if available
                if let createdAt = message.createdAt {
                    Text(createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(isSentByCurrentDevice ? .white.opacity(0.7) : .gray)
                } else {
                    // Placeholder to maintain layout even if timestamp not available
                    Text("--:--")
                        .font(.caption2)
                        .foregroundColor(isSentByCurrentDevice ? .white.opacity(0.3) : .gray.opacity(0.3))
                }

                if isSentByCurrentDevice {
                    if message.readAt != nil {
                        HStack(spacing: -2) {
                            Text("✓")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text("✓")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else {
                        Text("✓")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isSentByCurrentDevice ? Color.blue : Color.gray.opacity(0.2))
        )
    }

    @ViewBuilder
    private func messageText(_ text: String, isError: Bool = false) -> some View {
        Text(text)
            .lineLimit(nil)
            .multilineTextAlignment(isSentByCurrentDevice ? .trailing : .leading)
            .foregroundColor(isSentByCurrentDevice ? .white : .primary)
            .font(.system(size: 16, weight: .regular, design: .default))
            .italic(isError)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private var fileMessageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show image inline if it's an image type and we have downloaded data
            if message.messageType == .image, let imageData = downloadedFileData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 300)
                    .cornerRadius(12)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .onTapGesture {
                        showImageViewer = true
                    }
                    .sheet(isPresented: $showImageViewer) {
                        ImageViewerSheet(image: uiImage)
                    }
            }

            HStack(spacing: 12) {
                // File icon
                Image(systemName: message.messageType == .image ? "photo.fill" : "doc.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isSentByCurrentDevice ? .white.opacity(0.9) : .indigo)

                VStack(alignment: .leading, spacing: 4) {
                    // File name
                    if let fileName = message.fileName {
                        Text(fileName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSentByCurrentDevice ? .white : .primary)
                            .lineLimit(2)
                    }

                    // File size
                    if let fileSize = message.fileSize {
                        Text(FileService.shared.formatFileSize(fileSize))
                            .font(.caption)
                            .foregroundColor(isSentByCurrentDevice ? .white.opacity(0.7) : .gray)
                    }

                    // Download status
                    if isDownloading {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Downloading...")
                                .font(.caption2)
                                .foregroundColor(isSentByCurrentDevice ? .white.opacity(0.7) : .gray)
                        }
                    } else if let error = downloadError {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else if downloadedFileData != nil {
                        Text("Downloaded")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                // Download/Save button
                if downloadedFileData == nil {
                    Button(action: {
                        Task {
                            await downloadFile()
                        }
                    }) {
                        Image(systemName: isDownloading ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 24))
                            .foregroundColor(isSentByCurrentDevice ? .white.opacity(0.8) : .indigo)
                    }
                } else {
                    Button(action: {
                        saveFileToPhotos()
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 24))
                            .foregroundColor(isSentByCurrentDevice ? .white.opacity(0.8) : .indigo)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .onAppear {
            // Auto-download images
            if message.messageType == .image && downloadedFileData == nil {
                Task {
                    await downloadFile()
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

    @MainActor
    private func downloadFile() async {
        guard let fileUrl = message.fileUrl else {
            downloadError = "No file URL"
            return
        }

        guard let keyString = message.encryptionKey ?? conversationEncryptionKey else {
            downloadError = "No encryption key"
            return
        }

        guard let nonce = message.nonce, let tag = message.tag else {
            downloadError = "Missing encryption metadata"
            return
        }

        isDownloading = true
        downloadError = nil

        do {
            print("[DEBUG] ConversationMessageRow - Downloading file from: \(fileUrl)")

            // Download encrypted file (binary data)
            let encryptedBinaryData = try await APIService.shared.downloadFile(url: fileUrl)

            print("[DEBUG] ConversationMessageRow - Downloaded \(encryptedBinaryData.count) bytes, decrypting...")

            // Convert binary data to base64 string for decryption
            let ciphertextBase64 = encryptedBinaryData.base64EncodedString()

            // Decrypt file using nonce and tag from message metadata
            let key = try CryptoManager.keyFromBase64String(keyString)
            let encryptedFile = EncryptedFile(ciphertext: ciphertextBase64, nonce: nonce, tag: tag)
            let decryptedData = try FileService.shared.decryptFile(encryptedFile, key: key)

            downloadedFileData = decryptedData
            print("[DEBUG] ConversationMessageRow - File decrypted successfully: \(decryptedData.count) bytes")

            isDownloading = false
        } catch {
            print("[ERROR] ConversationMessageRow - Failed to download file: \(error)")
            downloadError = "Download failed"
            isDownloading = false
        }
    }

    private func saveFileToPhotos() {
        guard let fileData = downloadedFileData else { return }

        // For images, save to photo library
        if message.messageType == .image, let uiImage = UIImage(data: fileData) {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            print("[DEBUG] ConversationMessageRow - Image saved to Photos")
        } else {
            // For other files, share via share sheet
            let activityVC = UIActivityViewController(
                activityItems: [fileData],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }

}

// MARK: - Image Viewer Sheet

struct ImageViewerSheet: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    // Reset if zoomed out too far
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    }
                                }
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
