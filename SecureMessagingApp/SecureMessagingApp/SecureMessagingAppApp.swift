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
        guard url.scheme == "securemsg" else { return }
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let messageId = components.path.components(separatedBy: "/").last,
           let fragment = components.fragment {
            
            let fullURL = "https://whisper.stratholme.eu/api/message/\(messageId)#\(fragment)"
            
            NotificationCenter.default.post(
                name: NSNotification.Name("HandleSecureMessageURL"),
                object: fullURL
            )
        }
    }
}