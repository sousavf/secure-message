import SwiftUI
import CryptoKit

struct ReceiveView: View {
    @State private var linkText = ""
    @State private var decryptedMessage: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    @StateObject private var apiService = APIService()
    private let linkManager = LinkManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Secure Message Link")
                        .font(.headline)
                    
                    TextField("Paste secure message link here", text: $linkText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                if let message = decryptedMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Decrypted Message")
                            .font(.headline)
                        
                        ScrollView {
                            Text(message)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 200)
                        
                        Button("Copy Message") {
                            UIPasteboard.general.string = message
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: processLink) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isProcessing ? "Processing..." : "Retrieve Message")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    
                    Button("Paste from Clipboard") {
                        if let clipboardText = UIPasteboard.general.string {
                            linkText = clipboardText
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Receive")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onChange(of: linkText) { _, newValue in
            if decryptedMessage != nil {
                decryptedMessage = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleSecureMessageURL"))) { notification in
            if let url = notification.object as? String {
                linkText = url
                processLink()
            }
        }
    }
    
    private func processLink() {
        guard !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isProcessing = true
        decryptedMessage = nil
        
        Task {
            do {
                let parsedLink = try linkManager.parseLink(linkText.trimmingCharacters(in: .whitespacesAndNewlines))
                let encryptedMessage = try await apiService.retrieveMessage(id: parsedLink.messageId)
                let decrypted = try CryptoManager.decrypt(encryptedMessage: encryptedMessage, key: parsedLink.key)
                
                await MainActor.run {
                    decryptedMessage = decrypted
                    isProcessing = false
                    linkText = ""
                    CryptoManager.securelyErase(&linkText)
                }
            } catch NetworkError.messageConsumed {
                await MainActor.run {
                    errorMessage = "This message has already been read and destroyed."
                    showingError = true
                    isProcessing = false
                }
            } catch NetworkError.messageExpired {
                await MainActor.run {
                    errorMessage = "This message has expired."
                    showingError = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isProcessing = false
                }
            }
        }
    }
}

#Preview {
    ReceiveView()
}