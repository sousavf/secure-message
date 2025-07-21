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
        guard pathComponents.count >= 2,
              url.fragment != nil else { return }
        
        // Convert preview links to direct links for the app
        var finalURL = url.absoluteString
        if pathComponents.count == 3 && pathComponents[2] == "preview" {
            // Remove "/preview" from the URL
            finalURL = finalURL.replacingOccurrences(of: "/preview#", with: "#")
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("HandleSecureMessageURL"),
            object: finalURL
        )
    }
}
