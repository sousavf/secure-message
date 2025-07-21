import SwiftUI
import CryptoKit

struct ComposeView: View {
    @State private var messageText = ""
    @State private var isEncrypting = false
    @State private var shareableLink: String?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @FocusState private var isTextEditorFocused: Bool
    
    @StateObject private var apiService = APIService()
    private let linkManager = LinkManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 40))
                            .foregroundStyle(.indigo)
                        
                        Text("Create Secure Message")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your message will be encrypted and can only be read once")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Message Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Message")
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
                                Text("Type your secure message here...")
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
                                        UIPasteboard.general.string = link
                                        // Add haptic feedback
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                    } label: {
                                        HStack {
                                            Image(systemName: "doc.on.doc")
                                            Text("Copy")
                                        }
                                        .frame(maxWidth: .infinity)
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
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
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
                Button(action: encryptAndUpload) {
                    HStack(spacing: 8) {
                        if isEncrypting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "lock.fill")
                        }
                        Text(isEncrypting ? "Encrypting..." : "Create Secure Message")
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
    }
    
    private func encryptAndUpload() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isEncrypting = true
        shareableLink = nil
        
        Task {
            do {
                let key = CryptoManager.generateKey()
                let encryptedMessage = try CryptoManager.encrypt(message: messageText, key: key)
                let messageId = try await apiService.createMessage(encryptedMessage)
                
                let link = linkManager.generateShareableLink(messageId: messageId, key: key)
                
                await MainActor.run {
                    shareableLink = link
                    isEncrypting = false
                    messageText = ""
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
