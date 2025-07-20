import SwiftUI
import CryptoKit

struct ComposeView: View {
    @State private var messageText = ""
    @State private var isEncrypting = false
    @State private var shareableLink: String?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    @StateObject private var apiService = APIService()
    private let linkManager = LinkManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Secure Message")
                        .font(.headline)
                    
                    TextEditor(text: $messageText)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                if let link = shareableLink {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shareable Link")
                            .font(.headline)
                        
                        Text(link)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        HStack {
                            Button("Copy Link") {
                                UIPasteboard.general.string = link
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Share") {
                                showingShareSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: encryptAndUpload) {
                    HStack {
                        if isEncrypting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isEncrypting ? "Encrypting..." : "Create Secure Message")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEncrypting)
            }
            .padding()
            .navigationTitle("Compose")
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
                    CryptoManager.securelyErase(&messageText)
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