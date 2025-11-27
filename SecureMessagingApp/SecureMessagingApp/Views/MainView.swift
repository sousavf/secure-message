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
            // Parse the URL to determine the correct routing
            if let url = notification.object as? URL {
                let urlString = url.absoluteString

                // Check if this is a conversation link (/join/{id}) or message link
                if urlString.contains("/join/") {
                    // This is a conversation join link - route to Conversations tab
                    selectedTab = 0
                    // Post a notification so ConversationListView can handle the join
                    // Use delay to ensure ConversationListView has initialized its listeners
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("HandleConversationDeepLink"),
                            object: url
                        )
                    }
                } else {
                    // This is a message link - route to Receive tab
                    selectedTab = 2
                }
            }
        }
    }
}

#Preview {
    MainView()
}