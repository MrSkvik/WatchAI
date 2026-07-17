import SwiftUI

@main
struct WatchAIApp: App {
    @State private var sessionManager = PhoneSessionManager.shared

    var body: some Scene {
        WindowGroup {
            StatusView()
                .environment(sessionManager)
        }
    }
}
