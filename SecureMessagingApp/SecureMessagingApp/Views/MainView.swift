import SwiftUI

struct MainView: View {
    @State private var selectedTab = 0
    @FocusState private var isAnyFieldFocused: Bool
    @State private var deviceId: String = {
        // Try to load deviceId from UserDefaults, or generate a new UUID
        if let savedId = UserDefaults.standard.string(forKey: "deviceId") {
            return savedId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "deviceId")
            return newId
        }
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationListView(deviceId: deviceId)
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Conversations")
                }
                .tag(0)

            ComposeView()
                .tabItem {
                    Image(systemName: "lock.doc")
                    Text("Compose")
                }
                .tag(1)

            ReceiveView()
                .tabItem {
                    Image(systemName: "envelope.open.fill")
                    Text("Receive")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .tint(.indigo)
        .onChange(of: selectedTab) { _, _ in
            isAnyFieldFocused = false
            // Dismiss keyboard when switching tabs
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleSecureMessageURL"))) { notification in
            // Switch to Receive tab when Universal Link is handled
            selectedTab = 1
        }
    }
}

#Preview {
    MainView()
}