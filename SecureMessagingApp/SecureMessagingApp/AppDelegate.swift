import UIKit
import UserNotifications
import os.log

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = OSLog(subsystem: "pt.sousavf.Safe-Whisper", category: "AppDelegate")

    // MARK: - UIApplicationDelegate Methods

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[DEBUG] AppDelegate - Application did finish launching")

        // Set push notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request push notification permissions and register for remote notifications
        // Note: requestAuthorization() already calls registerForRemoteNotifications() if user grants permission
        Task {
            print("[DEBUG] AppDelegate - Requesting authorization")
            os_log("[APNs] Requesting notification authorization", log: self.logger, type: .info)
            let authorized = await PushNotificationService.shared.requestAuthorization()
            print("[DEBUG] AppDelegate - Authorization result: \(authorized)")
            os_log("[APNs] Authorization result: %{public}@", log: self.logger, type: .info, authorized ? "GRANTED" : "DENIED")
        }

        return true
    }

    /// Called when device successfully registers for remote notifications
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        let tokenPrefix = String(token.prefix(16))
        os_log("[APNs] Registered for remote notifications, token: %@...", log: self.logger, type: .info, tokenPrefix)
        os_log("[APNs] Token length: %d", log: self.logger, type: .debug, token.count)
        print("[DEBUG] AppDelegate - Registered for remote notifications, token: \(tokenPrefix)...")
        print("[DEBUG] AppDelegate - Token length: \(token.count)")

        // Register the token with our backend
        os_log("[APNs] About to register token with backend", log: self.logger, type: .info)
        print("[DEBUG] AppDelegate - About to register token with backend")
        Task {
            os_log("[APNs] Inside Task, calling registerToken", log: self.logger, type: .debug)
            print("[DEBUG] AppDelegate - Inside Task, calling registerToken")
            await PushNotificationService.shared.registerToken(token)
            os_log("[APNs] registerToken completed", log: self.logger, type: .info)
            print("[DEBUG] AppDelegate - registerToken completed")
        }
    }

    /// Called when device fails to register for remote notifications
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[ERROR] AppDelegate - Failed to register for remote notifications: \(error)")
    }

    /// Handle remote notification when app is in background or foreground
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[DEBUG] AppDelegate - Received remote notification")

        // Check if this is a silent notification (content-available)
        let aps = userInfo["aps"] as? [String: Any]
        let contentAvailable = aps?["content-available"] as? Int == 1

        if contentAvailable {
            // This is a silent push notification
            print("[DEBUG] AppDelegate - Silent push received")
            PushNotificationService.shared.handleSilentPush(userInfo: userInfo)
            completionHandler(.newData)
        } else {
            // Regular notification - already handled by UNUserNotificationCenter delegate
            completionHandler(.noData)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate Methods

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("[DEBUG] AppDelegate - Notification received while in foreground")

        let userInfo = notification.request.content.userInfo

        // For security, we don't show the notification UI (silent)
        // Instead, we trigger a refresh in the background
        PushNotificationService.shared.handleSilentPush(userInfo: userInfo)

        // Don't show notification badge/alert for silent pushes
        completionHandler([])
    }

    /// Handle user tapping on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("[DEBUG] AppDelegate - User tapped on notification")

        let userInfo = response.notification.request.content.userInfo

        // First, handle the silent push to refresh data
        PushNotificationService.shared.handleSilentPush(userInfo: userInfo)

        // Then, route to the conversation if this is a conversation notification
        if let conversationHash = userInfo["c"] as? String {
            print("[DEBUG] AppDelegate - Notification is for conversation hash: \(conversationHash)")

            // Post notification to route to the conversation
            NotificationCenter.default.post(
                name: NSNotification.Name("PushNotificationConversationTapped"),
                object: conversationHash
            )
        }

        completionHandler()
    }

    // MARK: - URL Scheme Handling

    /// Handle deep links via custom URL scheme (securemsg://)
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        print("[DEBUG] AppDelegate - Handling URL: \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.scheme == "securemsg" else {
            print("[ERROR] AppDelegate - Invalid URL scheme")
            return false
        }

        // Parse the URL path: securemsg://message/{id} or securemsg://conversation/{id}
        let pathComponents = url.path.split(separator: "/").map(String.init)

        if pathComponents.count >= 2 {
            let type = pathComponents[0]  // "message" or "conversation"
            let id = pathComponents[1]

            print("[DEBUG] AppDelegate - Deep link type: \(type), id: \(id)")

            if type == "message" {
                // Handle message link - route to receive tab
                let messageUrl = URL(string: "https://privileged.stratholme.eu/\(id)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("HandleSecureMessageURL"),
                    object: messageUrl
                )
            } else if type == "conversation" {
                // Handle conversation link - construct the join URL
                // Format: https://privileged.stratholme.eu/join/{conversationId}#{encryptionKey}
                let encryptionKey = KeyStore.shared.retrieveKey(for: UUID(uuidString: id) ?? UUID()) ?? ""
                let joinUrlString = "https://privileged.stratholme.eu/join/\(id)\(encryptionKey.isEmpty ? "" : "#" + encryptionKey)"

                if let joinUrl = URL(string: joinUrlString) {
                    print("[DEBUG] AppDelegate - Posting conversation join URL: \(joinUrl.absoluteString)")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("HandleSecureMessageURL"),
                        object: joinUrl
                    )
                } else {
                    print("[ERROR] AppDelegate - Failed to construct conversation URL")
                }
            }

            return true
        }

        print("[ERROR] AppDelegate - Invalid URL path format")
        return false
    }
}
