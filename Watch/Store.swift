import Foundation
import SwiftData

/// Persisted conversation thread. The Watch app is the source of truth for
/// chat history — the iPhone host app is stateless aside from each thread's
/// live in-memory model context.
@Model
final class ThreadEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "New Chat", updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
    }
}

@Model
final class MessageEntity {
    @Attribute(.unique) var id: UUID
    var threadID: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), threadID: UUID, roleRaw: String, text: String, createdAt: Date = .now) {
        self.id = id
        self.threadID = threadID
        self.roleRaw = roleRaw
        self.text = text
        self.createdAt = createdAt
    }

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }
}
