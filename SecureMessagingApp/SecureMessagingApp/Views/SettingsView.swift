import SwiftUI

struct SettingsView: View {
    @AppStorage("serverURL") private var serverURL = "http://localhost:8080"
    @AppStorage("domainURL") private var domainURL = "https://yourdomain.com"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Configuration")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Backend Server URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("http://localhost:8080", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share Domain URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://yourdomain.com", text: $domainURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
                
                Section(header: Text("Security Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("End-to-End Encryption")
                            .font(.headline)
                        Text("Messages are encrypted using AES-256-GCM before leaving your device. Encryption keys are never sent to the server.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("One-Time Access")
                            .font(.headline)
                        Text("Messages are automatically destroyed after being read once or after 24 hours.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zero-Knowledge Architecture")
                            .font(.headline)
                        Text("The server never has access to your message content or encryption keys.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Privacy")) {
                    Link("Privacy Policy", destination: URL(string: "https://yourdomain.com/privacy")!)
                        .foregroundColor(.blue)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}