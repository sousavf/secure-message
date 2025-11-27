import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 40))
                            .foregroundStyle(.indigo)

                        Text("Secure Messaging")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Privacy and security information")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Security Features
                    VStack(spacing: 16) {
                        SecurityFeatureCard(
                            icon: "lock.shield.fill",
                            title: "End-to-End Encryption",
                            description: "Whispers are encrypted using AES-256-GCM before leaving your device. Encryption keys are never sent to the server.",
                            iconColor: .green
                        )
                        
                        SecurityFeatureCard(
                            icon: "timer",
                            title: "One-Time Access",
                            description: "Whispers are automatically destroyed after being read once or after 24 hours.",
                            iconColor: .orange
                        )
                        
                        SecurityFeatureCard(
                            icon: "eye.slash.fill",
                            title: "Zero-Knowledge Architecture",
                            description: "The server never has access to your whisper content or encryption keys.",
                            iconColor: .blue
                        )
                        
                        SecurityFeatureCard(
                            icon: "network.slash",
                            title: "No Data Collection",
                            description: "We don't track, store, or analyze your personal data or whispers.",
                            iconColor: .purple
                        )
                    }
                    
                    // How It Works Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How It Works")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            HowItWorksStep(
                                number: "1",
                                title: "Write Whisper",
                                description: "Type your safe whisper"
                            )
                            
                            HowItWorksStep(
                                number: "2",
                                title: "Encrypt & Upload",
                                description: "Whisper is encrypted locally and uploaded"
                            )
                            
                            HowItWorksStep(
                                number: "3",
                                title: "Share Link",
                                description: "Share the secure link with your recipient"
                            )
                            
                            HowItWorksStep(
                                number: "4",
                                title: "Read Once",
                                description: "Whisper is decrypted and destroyed after reading"
                            )
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(12)
                    
                    // App Info Section
                    VStack(spacing: 16) {
                        Text("App Information")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            InfoRow(label: "Version", value: "2.0.0")
                            InfoRow(label: "Build", value: "15")
                            InfoRow(label: "Server", value: "privileged.stratholme.eu")
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(12)
                    
                    // Useful Links Section
                    VStack(spacing: 16) {
                        Text("Useful Links")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            LinkButton(title: "Support & Contact", url: "https://whisper.stratholme.eu/support/contact", icon: "questionmark.circle.fill")
                            LinkButton(title: "About Me", url: "https://whisper.stratholme.eu/about/me", icon: "person.circle.fill")
                            LinkButton(title: "Privacy Policy", url: "https://whisper.stratholme.eu/privacy/policy", icon: "shield.fill")
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SecurityFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct HowItWorksStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.indigo)
                .cornerRadius(14)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct LinkButton: View {
    let title: String
    let url: String
    let icon: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.indigo)
                    .frame(width: 20)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}
