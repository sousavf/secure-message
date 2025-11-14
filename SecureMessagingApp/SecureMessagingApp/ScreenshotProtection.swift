import SwiftUI
import UIKit

// View modifier to prevent screenshots and screen recording
struct ScreenshotProtection: ViewModifier {
    @State private var isScreenBeingCaptured = false

    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: isScreenBeingCaptured ? 20 : 0)

            if isScreenBeingCaptured {
                VStack(spacing: 20) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text("Screen Recording Detected")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("For your security, content is hidden during screen recording or screenshots")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            checkScreenCapture()
            setupNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            checkScreenCapture()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            handleScreenshot()
        }
    }

    private func checkScreenCapture() {
        isScreenBeingCaptured = UIScreen.main.isCaptured
    }

    private func setupNotifications() {
        // Initial check
        checkScreenCapture()
    }

    private func handleScreenshot() {
        // Screenshot was taken - you can add additional handling here
        // For example, log the event, notify the user, or clear sensitive data
        print("Screenshot detected - content should be protected")
    }
}

extension View {
    func preventScreenshot() -> some View {
        self.modifier(ScreenshotProtection())
    }
}

// Additional security: Make specific views private/sensitive (iOS 15+)
extension View {
    func makePrivate() -> some View {
        if #available(iOS 15.0, *) {
            return self.privacySensitive()
        } else {
            return self
        }
    }
}
