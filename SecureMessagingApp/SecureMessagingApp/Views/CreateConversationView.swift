import SwiftUI

struct CreateConversationView: View {
    var deviceId: String
    var onConversationCreated: (Conversation) -> Void
    @Environment(\.dismiss) var dismiss

    @StateObject private var apiService = APIService.shared
    @State private var selectedTTLHours: Int = 24
    @State private var isCreating = false
    @State private var errorMessage: String?

    let ttlOptions = [1, 6, 12, 24, 48, 72]

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.indigo)

                        VStack(spacing: 8) {
                            Text("Create New Conversation")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Start a secure, encrypted conversation with anyone")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Conversation Duration")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("Messages will automatically expire after this time")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Picker("Duration", selection: $selectedTTLHours) {
                                ForEach(ttlOptions, id: \.self) { hours in
                                    HStack {
                                        Text(formatDuration(hours))
                                            .font(.body)
                                        Spacer()
                                        if selectedTTLHours == hours {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.indigo)
                                        }
                                    }
                                    .tag(hours)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(.indigo)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Features")
                                .font(.headline)
                                .fontWeight(.semibold)

                            FeatureItem(
                                icon: "lock.fill",
                                title: "End-to-End Encrypted",
                                description: "Messages are encrypted on your device"
                            )

                            FeatureItem(
                                icon: "clock.fill",
                                title: "Auto-Expiring",
                                description: "Messages automatically delete after \(formatDuration(selectedTTLHours))"
                            )

                            FeatureItem(
                                icon: "eye.slash.fill",
                                title: "Private",
                                description: "Server never has access to plaintext"
                            )
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    Spacer()

                    VStack(spacing: 12) {
                        Button(action: createConversation) {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Conversation")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(isCreating)

                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .foregroundColor(.indigo)
                                .background(Color.indigo.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .disabled(isCreating)
                    }
                }
                .padding(24)

                if isCreating {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
            .background(Color(.systemBackground))
        }
    }

    private func createConversation() {
        isCreating = true
        Task {
            do {
                print("[DEBUG] CreateConversationView - Starting createConversation with TTL: \(selectedTTLHours), deviceId: \(deviceId)")
                let newConversation = try await apiService.createConversation(
                    ttlHours: selectedTTLHours,
                    deviceId: deviceId
                )
                await MainActor.run {
                    print("[DEBUG] CreateConversationView - Conversation created successfully: \(newConversation.id)")
                    onConversationCreated(newConversation)
                    dismiss()
                }
            } catch let error as NetworkError {
                print("[ERROR] CreateConversationView - NetworkError caught: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            } catch {
                print("[ERROR] CreateConversationView - Unexpected error caught: \(error)")
                print("[ERROR] CreateConversationView - Error type: \(type(of: error))")
                print("[ERROR] CreateConversationView - Error description: \(String(describing: error))")
                await MainActor.run {
                    errorMessage = "Failed to create conversation: \(error)"
                    isCreating = false
                }
            }
        }
    }

    private func formatDuration(_ hours: Int) -> String {
        if hours < 24 {
            return "\(hours)h"
        } else if hours == 24 {
            return "1 day"
        } else {
            let days = hours / 24
            return "\(days) days"
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.indigo)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    CreateConversationView(deviceId: "preview") { _ in }
}
