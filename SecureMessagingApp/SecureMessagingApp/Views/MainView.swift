import SwiftUI

struct MainView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ComposeView()
                .tabItem {
                    Image(systemName: "square.and.pencil")
                    Text("Compose")
                }
                .tag(0)
            
            ReceiveView()
                .tabItem {
                    Image(systemName: "envelope.open")
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
        .accentColor(.blue)
    }
}

#Preview {
    MainView()
}