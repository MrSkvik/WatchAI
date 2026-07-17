import Foundation
import Observation
import WatchConnectivity

/// Runs on the iPhone. Relays generation requests from the Watch to
/// `ModelEngine` and streams the results back over WatchConnectivity.
///
/// Known v1 limitation: `WCSession.sendMessage` requires the counterpart app
/// to be reachable (foreground/active nearby), so this works reliably when
/// the iPhone is unlocked and nearby — the normal case while actively
/// chatting from the Watch. It is not designed to wake a backgrounded/locked
/// iPhone to serve a request.
@MainActor
@Observable
final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    var isReachable = false
    var modelStatus: ModelStatusUpdate = .initial

    private let engine = ModelEngine()
    private var session: WCSession?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session

        // Start downloading/loading the model as soon as the app launches,
        // rather than waiting for the first message from the Watch.
        Task {
            try? await engine.ensureLoaded { [weak self] status in
                self?.modelStatus = status
                self?.broadcast(.modelStatus, status)
            }
        }
    }

    private func broadcast<T: Encodable>(_ kind: WCMessageKind, _ payload: T) {
        guard let session, session.isReachable else { return }
        session.sendMessage(WCEnvelope.encode(kind, payload), replyHandler: nil, errorHandler: nil)
    }

    private func handle(_ request: GenerateRequest) async {
        do {
            let stream = try await engine.streamResponse(
                threadID: request.threadID,
                userText: request.text
            ) { [weak self] status in
                self?.modelStatus = status
                self?.broadcast(.modelStatus, status)
            }

            for try await chunk in stream {
                broadcast(.tokenChunk, TokenChunk(requestID: request.requestID, threadID: request.threadID, text: chunk))
            }
            broadcast(.generationDone, GenerationDone(requestID: request.requestID, threadID: request.threadID))
        } catch {
            broadcast(
                .generationError,
                GenerationError(requestID: request.requestID, threadID: request.threadID, message: error.localizedDescription)
            )
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isReachable = isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isReachable = isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard WCEnvelope.kind(of: message) == .generateRequest,
              let request = WCEnvelope.decode(GenerateRequest.self, from: message)
        else { return }

        Task { @MainActor in
            await self.handle(request)
        }
    }
}
