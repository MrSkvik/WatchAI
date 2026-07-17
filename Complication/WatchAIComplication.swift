import SwiftUI
import WidgetKit

/// Minimal Watch face complication — no live data, just a quick-launch icon
/// for the app. Tapping it opens WatchAI to the thread list.
struct WatchAIComplicationEntry: TimelineEntry {
    let date: Date
}

struct WatchAIComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchAIComplicationEntry {
        WatchAIComplicationEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchAIComplicationEntry) -> Void) {
        completion(WatchAIComplicationEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchAIComplicationEntry>) -> Void) {
        completion(Timeline(entries: [WatchAIComplicationEntry(date: .now)], policy: .never))
    }
}

struct WatchAIComplicationView: View {
    var entry: WatchAIComplicationEntry

    var body: some View {
        Image(systemName: "bubble.left.and.bubble.right.fill")
    }
}

@main
struct WatchAIComplication: Widget {
    let kind = "WatchAIComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchAIComplicationProvider()) { entry in
            WatchAIComplicationView(entry: entry)
        }
        .configurationDisplayName("WatchAI")
        .description("Quick access to your AI chat.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}
