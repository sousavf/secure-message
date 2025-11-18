import SwiftUI
import CryptoKit
import PhotosUI

struct ComposeView: View {
    @State private var messageText = ""
    @State private var isEncrypting = false
    @State private var shareableLink: String?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isCopyButtonPressed = false
    @State private var isNewMessageButtonPressed = false
    @FocusState private var isTextEditorFocused: Bool

    @StateObject private var apiService = APIService()
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

                            Text("\(messageText.count) characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    }
                    
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
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEncrypting)
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
    }
    
    private func encryptAndUpload(scrollProxy: ScrollViewProxy) {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isEncrypting = true
        shareableLink = nil

        Task {
            do {
                let key = CryptoManager.generateKey()

                let encryptedMessage = try CryptoManager.encrypt(message: messageText, key: key)

                // Send message to server
                let messageId = try await apiService.createMessage(encryptedMessage, deviceId: nil)
                
                let link = linkManager.generateShareableLink(messageId: messageId, key: key)
                
                await MainActor.run {
                    shareableLink = link
                    isEncrypting = false
                    messageText = ""

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
