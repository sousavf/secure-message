import SwiftUI

struct MainView: View {
    @State private var selectedTab = 0
    @FocusState private var isAnyFieldFocused: Bool
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ComposeView()
                .tabItem {
                    Image(systemName: "lock.doc")
                    Text("Compose")
                }
                .tag(0)

            ReceiveView()
                .tabItem {
                    Image(systemName: "envelope.open.fill")
                    Text("Receive")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
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
        .preventScreenshot() // Enable screenshot and screen recording prevention
    }
}

#Preview {
    MainView()
}