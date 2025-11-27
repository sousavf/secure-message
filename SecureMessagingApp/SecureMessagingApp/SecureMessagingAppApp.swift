import SwiftUI

@main
struct SecureMessagingAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        // App came to foreground - force re-register token to ensure backend has it
                        Task {
                            print("[DEBUG] SecureMessagingAppApp - App entered foreground, force refreshing APNs token")
                            await PushNotificationService.shared.forceTokenRefresh()
                        }
                    }
                }
        }
    }
    
    func handleIncomingURL(_ url: URL) {
        print("App: Received URL: \(url.absoluteString)")
        
        guard url.scheme == "https" && url.host == "privileged.stratholme.eu" else { 
            print("App: URL scheme or host doesn't match")
            return 
        }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count >= 2,
              url.fragment != nil else { 
            print("App: URL doesn't have required components")
            return 
        }
        
        print("App: Valid Universal Link detected")
        
        // Convert preview links to direct links for the app
        var finalURL = url.absoluteString
        if pathComponents.count == 3 && pathComponents[2] == "preview" {
            // Remove "/preview" from the URL
            finalURL = finalURL.replacingOccurrences(of: "/preview#", with: "#")
            print("App: Converted preview link to direct link")
        }
        
        print("App: Posting notification with URL: \(finalURL)")

        // Add slight delay to ensure app is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let url = URL(string: finalURL) {
                print("App: Successfully created URL object, posting notification")
                NotificationCenter.default.post(
                    name: NSNotification.Name("HandleSecureMessageURL"),
                    object: url
                )
            } else {
                print("App: Failed to create URL object from: \(finalURL)")
            }
        }
    }
}
