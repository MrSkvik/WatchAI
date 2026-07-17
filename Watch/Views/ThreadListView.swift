import SwiftData
import SwiftUI

struct ThreadListView: View {
    @Environment(\.modelContext) private var context
    @Environment(WatchSessionManager.self) private var sessionManager
    @Query(sort: \ThreadEntity.updatedAt, order: .reverse) private var threads: [ThreadEntity]
    @Query private var allMessages: [MessageEntity]

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(threads) { thread in
                    NavigationLink(value: thread.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(thread.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(thread.updatedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteThreads)
            }
            .navigationTitle("Chats")
            .navigationDestination(for: UUID.self) { threadID in
                ChatView(threadID: threadID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: newThread) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .overlay {
                if threads.isEmpty {
                    ContentUnavailableView(
                        "No chats yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(sessionManager.isReachable ? "Tap + to start" : "Open WatchAI on your iPhone first")
                    )
                }
            }
        }
    }

    private func newThread() {
        let thread = ThreadEntity()
        context.insert(thread)
        path.append(thread.id)
    }

    private func deleteThreads(at offsets: IndexSet) {
        for index in offsets {
            let thread = threads[index]
            for message in allMessages where message.threadID == thread.id {
                context.delete(message)
            }
            context.delete(thread)
        }
    }
}
