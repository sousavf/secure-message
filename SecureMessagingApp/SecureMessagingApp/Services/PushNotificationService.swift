import Foundation
import UIKit
import UserNotifications
import CryptoKit
import os.log

class PushNotificationService {
    static let shared = PushNotificationService()

    private let apiService = APIService.shared
    private let tokenRefreshInterval: TimeInterval = 24 * 60 * 60  // 24 hours
    private let lastTokenRegistrationKey = "lastAPNsTokenRegistration"
    private let lastRegisteredTokenKey = "lastRegisteredAPNsToken"
    private let lastKnownAppVersionKey = "lastKnownAppVersion"
    private let logger = OSLog(subsystem: "pt.sousavf.Safe-Whisper", category: "APNs")

    // Get current app version from Info.plist
    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // Notification name for when new messages arrive
    static let newMessageReceivedNotification = NSNotification.Name("newMessageReceived")

    // Get the persistent device ID (same one used throughout the app)
    var persistentDeviceID: String {
        let defaults = UserDefaults.standard
        let deviceIdKey = "deviceId"  // Same key as MainView uses!

        // Try to get existing ID
        if let existingID = defaults.string(forKey: deviceIdKey) {
            return existingID
        }

        // Create new ID if doesn't exist (MainView should have already created this)
        let newID = UUID().uuidString
        defaults.set(newID, forKey: deviceIdKey)
        return newID
    }

    // MARK: - Public Methods

    /// Check if APNs token registration needs refresh (called on app launch)
    func refreshTokenIfNeeded() async {
        let defaults = UserDefaults.standard
        let lastRegistration = defaults.double(forKey: lastTokenRegistrationKey)
        let timeSinceLastRegistration = Date().timeIntervalSince1970 - lastRegistration

        // Re-register if more than 24 hours have passed
        if timeSinceLastRegistration > tokenRefreshInterval {
            print("[DEBUG] PushNotificationService - Token registration expired, requesting new token")
            // Request APNs to generate a new token (or refresh the existing one)
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else {
            print("[DEBUG] PushNotificationService - Token is fresh, no refresh needed")
        }
    }

    /// Force re-register APNs token (called when app comes to foreground)
    /// This ensures the backend always has a valid token even if app was backgrounded
    func forceTokenRefresh() async {
        print("[DEBUG] PushNotificationService - Force refreshing APNs token")
        os_log("[APNs] Force refreshing APNs token", log: self.logger, type: .info)

        // First, try to re-register with the last known token
        let defaults = UserDefaults.standard
        if let lastToken = defaults.string(forKey: lastRegisteredTokenKey) {
            os_log("[APNs] Attempting to re-register last known token", log: self.logger, type: .debug)
            print("[DEBUG] PushNotificationService - Attempting to re-register last known token")
            // Force re-registration by clearing the timestamp
            defaults.set(0, forKey: lastTokenRegistrationKey)
            await registerToken(lastToken)
        }

        // Then request a fresh token from Apple
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
            os_log("[APNs] Called registerForRemoteNotifications()", log: self.logger, type: .debug)
        }
    }

    /// Register APNs token with backend
    func registerToken(_ apnsToken: String) async {
        os_log("[APNs] registerToken() called with token: %{private}@...", log: self.logger, type: .info, String(apnsToken.prefix(16)))
        print("[DEBUG] PushNotificationService - registerToken() called")

        let deviceId = persistentDeviceID
        let defaults = UserDefaults.standard

        os_log("[APNs] Device ID: %{private}@", log: self.logger, type: .debug, deviceId)
        print("[DEBUG] PushNotificationService - Device ID: \(deviceId)")

        // Check for app version change - force re-registration on app update
        let lastKnownVersion = defaults.string(forKey: lastKnownAppVersionKey)
        if lastKnownVersion != currentAppVersion {
            os_log("[APNs] App version changed from %@ to %@ - forcing re-registration", log: self.logger, type: .info, lastKnownVersion ?? "unknown", currentAppVersion)
            print("[DEBUG] PushNotificationService - App version changed - forcing re-registration")
            defaults.set(currentAppVersion, forKey: lastKnownAppVersionKey)
            // Clear old registration data to force re-register
            defaults.set(0, forKey: lastTokenRegistrationKey)
        }

        // Check if token has been successfully registered before
        let lastToken = defaults.string(forKey: lastRegisteredTokenKey)
        let lastRegistrationTime = defaults.double(forKey: lastTokenRegistrationKey)
        let timeSinceLastRegistration = Date().timeIntervalSince1970 - lastRegistrationTime

        os_log("[APNs] Last token was: %{private}@", log: self.logger, type: .debug, lastToken ?? "NONE")
        os_log("[APNs] Time since last registration: %f seconds", log: self.logger, type: .debug, timeSinceLastRegistration)

        // Skip only if token is the same AND it was registered within the last 24 hours AND app version hasn't changed
        if lastToken == apnsToken && timeSinceLastRegistration < tokenRefreshInterval {
            os_log("[APNs] Token unchanged and recently registered, skipping registration", log: self.logger, type: .debug)
            print("[DEBUG] PushNotificationService - Token unchanged and recently registered, skipping registration")
            return
        }

        os_log("[APNs] Registering APNs token for device: %{private}@", log: self.logger, type: .info, deviceId)
        print("[DEBUG] PushNotificationService - Registering APNs token for device: \(deviceId)")

        do {
            os_log("[APNs] Creating RegisterDeviceTokenRequest with token", log: self.logger, type: .debug)
            let request = RegisterDeviceTokenRequest(apnsToken: apnsToken)

            // Create request manually to add X-Device-ID header
            let urlString = "https://privileged.stratholme.eu/api/devices/token"
            guard let url = URL(string: urlString) else {
                os_log("[APNs] Invalid URL: %@", log: self.logger, type: .error, urlString)
                print("[ERROR] PushNotificationService - Invalid URL: \(urlString)")
                return
            }

            os_log("[APNs] URL is valid, creating URLRequest", log: self.logger, type: .debug)
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

            os_log("[APNs] Encoding request body", log: self.logger, type: .debug)
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)

            os_log("[APNs] Making URLSession request to %@", log: self.logger, type: .info, urlString)
            print("[DEBUG] PushNotificationService - Making URLSession request to \(urlString)")
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            os_log("[APNs] Received response from server", log: self.logger, type: .debug)
            if let httpResponse = response as? HTTPURLResponse {
                os_log("[APNs] HTTP Status: %d", log: self.logger, type: .info, httpResponse.statusCode)
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    os_log("[APNs] Token registered successfully with status %d", log: self.logger, type: .info, httpResponse.statusCode)
                    print("[DEBUG] PushNotificationService - APNs token registered successfully")
                    // Save registration timestamp and token for future checks
                    defaults.set(Date().timeIntervalSince1970, forKey: lastTokenRegistrationKey)
                    defaults.set(apnsToken, forKey: lastRegisteredTokenKey)
                } else {
                    let msg = "Failed to register token, status: \(httpResponse.statusCode)"
                    os_log("[APNs] %@", log: self.logger, type: .error, msg)
                    print("[ERROR] PushNotificationService - \(msg)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        os_log("[APNs] Response: %@", log: self.logger, type: .error, responseString)
                        print("[ERROR] PushNotificationService - Response: \(responseString)")
                    }
                }
            } else {
                os_log("[APNs] Invalid response type", log: self.logger, type: .error)
                print("[ERROR] PushNotificationService - Invalid response type")
            }
        } catch {
            let msg = "Failed to register APNs token: \(error)"
            os_log("[APNs] %@", log: self.logger, type: .error, msg)
            print("[ERROR] PushNotificationService - \(msg)")
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))

            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }

    /// Request push notification permissions
    func requestAuthorization() async -> Bool {
        do {
            os_log("[APNs] Requesting UNUserNotificationCenter authorization", log: self.logger, type: .info)
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                os_log("[APNs] User GRANTED notification permission, calling registerForRemoteNotifications()", log: self.logger, type: .info)
                print("[DEBUG] PushNotificationService - User granted notification permission")
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                    os_log("[APNs] registerForRemoteNotifications() called", log: self.logger, type: .debug)
                }
            } else {
                os_log("[APNs] User DENIED notification permission", log: self.logger, type: .error)
                print("[DEBUG] PushNotificationService - User denied notification permission")
            }

            return granted
        } catch {
            os_log("[APNs] Failed to request authorization: %@", log: self.logger, type: .error, error.localizedDescription)
            print("[ERROR] PushNotificationService - Failed to request notification authorization: \(error)")
            return false
        }
    }

    /// Handle silent push notification (content-available)
    /// This is called when a silent push arrives while app is in background
    func handleSilentPush(userInfo: [AnyHashable: Any]) {
        print("[DEBUG] PushNotificationService - Handling silent push")

        // Extract conversation hash from push payload
        if let conversationHash = userInfo["c"] as? String {
            print("[DEBUG] PushNotificationService - Received push for conversation hash: \(conversationHash)")

            // Extract notification type if present
            var notificationInfo: [String: Any] = ["conversationHash": conversationHash]
            if let notificationType = userInfo["type"] as? String {
                print("[DEBUG] PushNotificationService - Notification type: \(notificationType)")
                notificationInfo["type"] = notificationType
            }

            // Notify observers to refresh messages or handle deletion/expiration
            NotificationCenter.default.post(
                name: PushNotificationService.newMessageReceivedNotification,
                object: nil,
                userInfo: notificationInfo
            )
        }
    }

    /// Check if notifications are enabled for the app
    func isNotificationEnabled() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isEnabled = settings.authorizationStatus == .authorized
        print("[DEBUG] PushNotificationService - Notifications enabled: \(isEnabled)")
        return isEnabled
    }

    // MARK: - Private Methods

    /// Hash conversation ID to match backend implementation
    /// Must use lowercase UUID string to match Java's UUID.toString() format
    private func hashConversationId(_ id: UUID) -> String {
        let lowercaseUUID = id.uuidString.lowercased()
        let data = lowercaseUUID.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return String(hashString.prefix(32))
    }
}

// MARK: - Request/Response Models

struct RegisterDeviceTokenRequest: Codable {
    let apnsToken: String
}

struct DeviceTokenResponse: Codable {
    let tokenId: String
    let deviceId: String
    let message: String
}
