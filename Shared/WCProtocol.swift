import Foundation

// Message types exchanged over WatchConnectivity between the Watch app and
// the iPhone host app. WCSession.sendMessage requires plist-compatible
// dictionaries, so every payload is JSON-encoded into a single `Data` value
// and tagged with a `kind` string.
//
// Streaming is implemented as a series of fire-and-forget `sendMessage` calls
// (one per token chunk) rather than a single reply, since WCSession's
// reply-handler mechanism only supports one reply per request. This requires
// both apps to be active/reachable for the duration of a generation — see
// the README's "Known v1 limitations" section.

enum WCMessageKind: String, Codable {
    case generateRequest   // Watch -> iPhone: ask for a completion
    case tokenChunk        // iPhone -> Watch: one streamed chunk of text
    case generationDone    // iPhone -> Watch: generation finished
    case generationError   // iPhone -> Watch: generation failed
    case modelStatus       // iPhone -> Watch: model download/load status
}

struct GenerateRequest: Codable, Sendable {
    let requestID: UUID
    let threadID: UUID
    let text: String
}

struct TokenChunk: Codable, Sendable {
    let requestID: UUID
    let threadID: UUID
    let text: String
}

struct GenerationDone: Codable, Sendable {
    let requestID: UUID
    let threadID: UUID
}

struct GenerationError: Codable, Sendable {
    let requestID: UUID
    let threadID: UUID
    let message: String
}

struct ModelStatusUpdate: Codable, Sendable {
    enum Status: String, Codable, Sendable {
        case notDownloaded
        case downloading
        case loading
        case ready
        case failed
    }

    let status: Status
    let progress: Double
    let detail: String

    static let initial = ModelStatusUpdate(status: .notDownloaded, progress: 0, detail: "Waiting for iPhone…")
}

/// Encodes/decodes the `[String: Any]` dictionaries WCSession requires.
enum WCEnvelope {
    static func encode<T: Encodable>(_ kind: WCMessageKind, _ payload: T) -> [String: Any] {
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        return ["kind": kind.rawValue, "payload": data]
    }

    static func kind(of message: [String: Any]) -> WCMessageKind? {
        guard let raw = message["kind"] as? String else { return nil }
        return WCMessageKind(rawValue: raw)
    }

    static func decode<T: Decodable>(_ type: T.Type, from message: [String: Any]) -> T? {
        guard let data = message["payload"] as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
