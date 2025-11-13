import SwiftUI
import CryptoKit
import PhotosUI

struct ComposeView: View {
    @State private var messageText = ""
    @State private var selectedImage: UIImage?
    @State private var isEncrypting = false
    @State private var shareableLink: String?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isCopyButtonPressed = false
    @State private var isNewMessageButtonPressed = false
    @State private var showingImagePicker = false
    @State private var showingSubscriptionView = false
    @State private var selectedTTLMinutes: Int = 1440 // Default: 24 hours
    @FocusState private var isTextEditorFocused: Bool

    // TTL options: 5 min, 15 min, 30 min, 1h, 6h, 12h, 24h, 48h
    private let ttlOptions: [(minutes: Int, label: String)] = [
        (5, "5 minutes"),
        (15, "15 minutes"),
        (30, "30 minutes"),
        (60, "1 hour"),
        (360, "6 hours"),
        (720, "12 hours"),
        (1440, "24 hours"),
        (2880, "48 hours")
    ]
    
    @StateObject private var apiService = APIService()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    private let linkManager = LinkManager()
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 40))
                            .foregroundStyle(.indigo)
                        
                        Text("Create Safe Whisper")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your whisper will be encrypted and can only be read once")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Message Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Whisper")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button {
                                    if subscriptionManager.subscriptionStatus == .premium {
                                        showingImagePicker = true
                                    } else {
                                        showingSubscriptionView = true
                                    }
                                } label: {
                                    Image(systemName: "photo")
                                        .foregroundColor(.blue)
                                }
                                
                                Text("\(messageText.count) characters")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .stroke(isTextEditorFocused ? Color.indigo : Color(.systemGray4), lineWidth: isTextEditorFocused ? 2 : 1)
                            
                            if messageText.isEmpty {
                                Text("Type your safe whisper here...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                            }
                            
                            TextEditor(text: $messageText)
                                .focused($isTextEditorFocused)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .scrollContentBackground(.hidden)
                        }
                        .frame(minHeight: 150)
                        .animation(.easeInOut(duration: 0.2), value: isTextEditorFocused)
                        
                        // Image Preview Section
                        if let image = selectedImage {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Attached Image")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Button("Remove") {
                                        selectedImage = nil
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                                    .clipped()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }

                    // TTL Selection Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.indigo)
                            Text("Message Lifetime")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()
                        }

                        Text("Choose how long your whisper will be available")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("TTL", selection: $selectedTTLMinutes) {
                            ForEach(ttlOptions, id: \.minutes) { option in
                                Text(option.label).tag(option.minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.indigo)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Generated Link Section
                    if let link = shareableLink {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(.green)
                                Text("Secure Link Generated")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                Text(link)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                
                                HStack(spacing: 12) {
                                    Button {
                                        // Visual feedback
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            isCopyButtonPressed = true
                                        }
                                        
                                        UIPasteboard.general.string = link
                                        // Add haptic feedback
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                        
                                        // Reset visual feedback
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                isCopyButtonPressed = false
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "doc.on.doc")
                                            Text("Copy")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .scaleEffect(isCopyButtonPressed ? 0.95 : 1.0)
                                        .opacity(isCopyButtonPressed ? 0.6 : 1.0)
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button {
                                        showingShareSheet = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Share")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                
                                Button {
                                    // Visual feedback
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        isNewMessageButtonPressed = true
                                    }

                                    // Clear everything to start a new message
                                    shareableLink = nil
                                    messageText = ""
                                    selectedImage = nil
                                    selectedTTLMinutes = 1440 // Reset to default 24 hours

                                    // Reset visual feedback
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            isNewMessageButtonPressed = false
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                        Text("New Whisper")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .scaleEffect(isNewMessageButtonPressed ? 0.95 : 1.0)
                                    .opacity(isNewMessageButtonPressed ? 0.6 : 1.0)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .id("secureLinkSection")
                    }
                    
                    Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
                .navigationTitle("Compose")
                .navigationBarTitleDisplayMode(.large)
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextEditorFocused = false
                }
                
                // Action Button
                VStack {
                Button(action: { encryptAndUpload(scrollProxy: proxy) }) {
                    HStack(spacing: 8) {
                        if isEncrypting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "lock.fill")
                        }
                        Text(isEncrypting ? "Encrypting..." : "Create Safe Whisper")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil) || isEncrypting)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                }
                .background(Color(.systemBackground).ignoresSafeArea())
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let link = shareableLink {
                ActivityViewController(activityItems: [link])
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onChange(of: messageText) { _, newValue in
            // Reset the shareable link when user starts typing a new message
            if !newValue.isEmpty && shareableLink != nil {
                shareableLink = nil
            }
        }
        .onChange(of: selectedImage) { _, newValue in
            // Reset the shareable link when user selects an image
            if newValue != nil && shareableLink != nil {
                shareableLink = nil
            }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: Binding<PhotosPickerItem?>(
            get: { nil },
            set: { item in
                Task {
                    if let item = item,
                       let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        
                        // Compress image if needed for premium users (max 10MB)
                        let maxSize: Int64 = subscriptionManager.subscriptionStatus == .premium ? 10_485_760 : 102_400
                        
                        if let compressedImage = compressImage(image, maxSizeBytes: maxSize) {
                            await MainActor.run {
                                selectedImage = compressedImage
                            }
                        } else {
                            await MainActor.run {
                                errorMessage = "Image is too large. Please choose a smaller image."
                                showingError = true
                            }
                        }
                    }
                }
            }
        ))
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
    }
    
    private func encryptAndUpload(scrollProxy: ScrollViewProxy) {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil else {
            return
        }
        
        isEncrypting = true
        shareableLink = nil
        
        Task {
            do {
                let key = CryptoManager.generateKey()
                
                // Prepare message content
                var contentToEncrypt = messageText
                
                // If there's an image, convert it to base64 and append
                if let image = selectedImage {
                    let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
                    let base64Image = imageData.base64EncodedString()
                    
                    // Create a JSON structure containing both text and image
                    let messageContent = MessageContent(
                        text: messageText.isEmpty ? nil : messageText,
                        image: base64Image,
                        imageType: "jpeg"
                    )
                    
                    let encoder = JSONEncoder()
                    if let jsonData = try? encoder.encode(messageContent) {
                        contentToEncrypt = String(data: jsonData, encoding: .utf8) ?? messageText
                    }
                }
                
                let encryptedMessage = try CryptoManager.encrypt(message: contentToEncrypt, key: key)
                
                // Get device ID and send with message including TTL
                let deviceId = await DeviceIdentifierManager.shared.getDeviceId()
                let messageId = try await apiService.createMessage(encryptedMessage, deviceId: deviceId, ttlMinutes: selectedTTLMinutes)
                
                let link = linkManager.generateShareableLink(messageId: messageId, key: key)
                
                await MainActor.run {
                    shareableLink = link
                    isEncrypting = false
                    messageText = ""
                    selectedImage = nil
                    
                    // Auto-scroll to the secure link section
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            scrollProxy.scrollTo("secureLinkSection", anchor: .center)
                        }
                    }
                }
            } catch NetworkError.messageTooLarge(let message) {
                await MainActor.run {
                    errorMessage = message
                    showingError = true
                    isEncrypting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isEncrypting = false
                }
            }
        }
    }
    
    private func compressImage(_ image: UIImage, maxSizeBytes: Int64) -> UIImage? {
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, Int64(data.count) > maxSizeBytes && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        if let data = imageData, Int64(data.count) <= maxSizeBytes {
            return UIImage(data: data)
        }
        
        // If still too large, resize the image
        let maxDimension: CGFloat = 1024
        let size = image.size
        let aspectRatio = size.width / size.height
        
        let newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let resized = resizedImage,
           let finalData = resized.jpegData(compressionQuality: 0.8),
           Int64(finalData.count) <= maxSizeBytes {
            return resized
        }
        
        return nil
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ComposeView()
}
