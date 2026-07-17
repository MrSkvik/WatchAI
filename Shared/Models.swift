import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

/// A single chat message. Persisted on the Watch (source of truth for history);
/// mirrored as `MessageEntity` in Watch/Store.swift for SwiftData storage.
struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let threadID: UUID
    let role: MessageRole
    var text: String
    let createdAt: Date

    init(id: UUID = UUID(), threadID: UUID, role: MessageRole, text: String, createdAt: Date = .now) {
        self.id = id
        self.threadID = threadID
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}
