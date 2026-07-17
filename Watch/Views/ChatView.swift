import SwiftData
import SwiftUI

struct ChatView: View {
    let threadID: UUID

    @Environment(\.modelContext) private var context
    @Environment(WatchSessionManager.self) private var sessionManager
    @Query private var allMessages: [MessageEntity]
    @Query private var allThreads: [ThreadEntity]

    @State private var draft = ""
    @State private var isGenerating = false
    @State private var streamingText = ""
    @State private var activeRequestID: UUID?
    @State private var errorText: String?

    private var messages: [MessageEntity] {
        allMessages
            .filter { $0.threadID == threadID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var thread: ThreadEntity? {
        allThreads.first { $0.id == threadID }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubble(text: message.text, isUser: message.role == .user)
                            .id(message.id)
                    }
                    if isGenerating {
                        MessageBubble(text: streamingText.isEmpty ? "…" : streamingText, isUser: false)
                            .id("streaming")
                    }
                    if let errorText {
                        Text(errorText)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            .onChange(of: messages.count) { scrollToBottom(proxy) }
            .onChange(of: streamingText) { scrollToBottom(proxy) }
        }
        .navigationTitle(thread?.title ?? "Chat")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                TextField("Message", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
        }
        .onAppear(perform: wireCallbacks)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isGenerating {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }
        draft = ""
        errorText = nil

        let userMessage = MessageEntity(threadID: threadID, roleRaw: MessageRole.user.rawValue, text: text)
        context.insert(userMessage)

        if let thread {
            thread.updatedAt = .now
            if thread.title == "New Chat" {
                thread.title = String(text.prefix(30))
            }
        }

        let requestID = UUID()
        activeRequestID = requestID
        isGenerating = true
        streamingText = ""

        sessionManager.send(GenerateRequest(requestID: requestID, threadID: threadID, text: text))
    }

    private func wireCallbacks() {
        sessionManager.onChunk = { chunk in
            guard chunk.requestID == activeRequestID else { return }
            streamingText += chunk.text
        }

        sessionManager.onDone = { done in
            guard done.requestID == activeRequestID else { return }
            let assistantMessage = MessageEntity(
                threadID: threadID,
                roleRaw: MessageRole.assistant.rawValue,
                text: streamingText
            )
            context.insert(assistantMessage)
            thread?.updatedAt = .now
            isGenerating = false
            streamingText = ""
            activeRequestID = nil
        }

        sessionManager.onError = { err in
            guard err.requestID == activeRequestID else { return }
            errorText = err.message
            isGenerating = false
            streamingText = ""
            activeRequestID = nil
        }
    }
}
