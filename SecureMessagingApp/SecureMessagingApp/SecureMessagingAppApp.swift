import SwiftUI

@main
struct SecureMessagingAppApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "https" && url.host == "whisper.stratholme.eu" else { return }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count >= 3,
              pathComponents[1] == "api",
              pathComponents[2] == "messages",
              url.fragment != nil else { return }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("HandleSecureMessageURL"),
            object: url.absoluteString
        )
    }
}
