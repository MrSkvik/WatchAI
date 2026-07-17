import SwiftData
import SwiftUI

@main
struct WatchAIWatchApp: App {
    @State private var sessionManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            ThreadListView()
                .environment(sessionManager)
        }
        .modelContainer(for: [ThreadEntity.self, MessageEntity.self])
    }
}
