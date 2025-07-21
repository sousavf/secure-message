import SwiftUI
import CryptoKit

struct ReceiveView: View {
    @State private var linkText = ""
    @State private var decryptedMessage: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @FocusState private var isTextFieldFocused: Bool
    
    @StateObject private var apiService = APIService()
    private let linkManager = LinkManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.open.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.indigo)
                        
                        Text("Receive Safe Whisper")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Paste a safe whisper link to decrypt and read it")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Link Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Whisper Link")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if !linkText.isEmpty {
                                Button("Clear") {
                                    print("ReceiveView: User clicked Clear button")
                                    linkText = ""
                                    decryptedMessage = nil
                                }
                                .font(.caption)
                                .foregroundStyle(.indigo)
                            }
                        }
                        
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .stroke(isTextFieldFocused ? Color.indigo : Color(.systemGray4), lineWidth: isTextFieldFocused ? 2 : 1)
                                    .frame(height: 50)
                                
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 12)
                                    
                                    TextField("https://whisper.stratholme.eu/...", text: $linkText)
                                        .focused($isTextFieldFocused)
                                        .textFieldStyle(.plain)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .keyboardType(.URL)
                                    
                                    if !linkText.isEmpty {
                                        Button {
                                            linkText = ""
                                            decryptedMessage = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.trailing, 12)
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
                            
                            Button {
                                if let clipboardText = UIPasteboard.general.string {
                                    linkText = clipboardText
                                    // Add haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste from Clipboard")
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // Decrypted Message Section
                    if let message = decryptedMessage {
                        let _ = print("ReceiveView: Rendering decrypted message UI with content: '\(message)'")
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("Whisper Decrypted")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                ScrollView {
                                    Text(message)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                        .font(.body)
                                        .textSelection(.enabled)
                                }
                                .frame(maxHeight: 200)
                                
                                Button {
                                    UIPasteboard.general.string = message
                                    // Add haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy Whisper")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGreen).opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.large)
            .contentShape(Rectangle())
            .onTapGesture {
                isTextFieldFocused = false
            }
            
            // Action Button
            VStack {
                Button(action: processLink) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "envelope.open.fill")
                        }
                        Text(isProcessing ? "Decrypting..." : "Retrieve Whisper")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onChange(of: linkText) { oldValue, newValue in
            // Only clear decrypted message if user is actively changing the link text
            // Don't clear it if we're just clearing the text after successful decryption
            if !oldValue.isEmpty && !newValue.isEmpty && decryptedMessage != nil {
                print("ReceiveView: User changed link text, clearing decrypted message")
                decryptedMessage = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleSecureMessageURL"))) { notification in
            print("ReceiveView: Received HandleSecureMessageURL notification")
            if let url = notification.object as? String {
                print("ReceiveView: Setting linkText to: \(url)")
                linkText = url
                processLink()
            }
        }
    }
    
    private func processLink() {
        guard !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("ReceiveView: Link text is empty")
            return
        }
        
        print("ReceiveView: Starting to process link: \(linkText)")
        isProcessing = true
        decryptedMessage = nil
        
        Task {
            do {
                print("ReceiveView: Parsing link...")
                let parsedLink = try linkManager.parseLink(linkText.trimmingCharacters(in: .whitespacesAndNewlines))
                print("ReceiveView: Link parsed successfully. MessageID: \(parsedLink.messageId)")
                
                print("ReceiveView: Retrieving encrypted message from server...")
                let encryptedMessage = try await apiService.retrieveMessage(id: parsedLink.messageId)
                print("ReceiveView: Encrypted message retrieved successfully")
                
                print("ReceiveView: Decrypting message...")
                let decrypted = try CryptoManager.decrypt(encryptedMessage: encryptedMessage, key: parsedLink.key)
                print("ReceiveView: Message decrypted successfully. Length: \(decrypted.count) characters")
                
                await MainActor.run {
                    print("ReceiveView: Setting decrypted message in UI")
                    decryptedMessage = decrypted
                    isProcessing = false
                    // Don't clear linkText immediately to avoid triggering onChange
                    print("ReceiveView: UI updated with decrypted message")
                }
            } catch NetworkError.messageConsumed {
                print("ReceiveView: Error - Message already consumed")
                await MainActor.run {
                    errorMessage = "This whisper has already been read and destroyed."
                    showingError = true
                    isProcessing = false
                }
            } catch NetworkError.messageExpired {
                print("ReceiveView: Error - Message expired")
                await MainActor.run {
                    errorMessage = "This whisper has expired."
                    showingError = true
                    isProcessing = false
                }
            } catch {
                print("ReceiveView: Error - \(error)")
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
