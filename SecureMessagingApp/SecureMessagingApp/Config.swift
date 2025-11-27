import Foundation

/// Centralized configuration for the app
/// Change the baseURL here to switch between development and production environments
struct Config {
    /// Base URL for the backend API
    /// Change this to debug with different backend servers
    static let baseURL = "https://privileged.stratholme.eu"

    /// App Bundle Identifier
    static let bundleIdentifier = "pt.sousavf.Safe-Whisper"

    /// App Store ID for TestFlight and App Store
    static let appStoreID = "6740152345"
}
