import Foundation
import Observation
import WatchConnectivity

/// Runs on the Watch. Sends generate requests to the iPhone and republishes
/// streamed chunks/errors/status via simple callback slots.
///
/// Only one generation is expected to be in flight at a time (the Watch chat
/// UI disables sending a new message while one is streaming), so a single
/// set of callback slots — rewired by whichever `ChatView` is on screen — is
/// sufficient for v1.
@MainActor
@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    var isReachable = false
    var modelStatus: ModelStatusUpdate = .initial

    var onChunk: ((TokenChunk) -> Void)?
    var onDone: ((GenerationDone) -> Void)?
    var onError: ((GenerationError) -> Void)?

    private var session: WCSession?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func send(_ request: GenerateRequest) {
        guard let session, session.isReachable else {
            onError?(
                GenerationError(
                    requestID: request.requestID,
                    threadID: request.threadID,
                    message: "iPhone not reachable. Make sure the WatchAI app is installed and your iPhone is nearby and unlocked."
                )
            )
            return
        }

        session.sendMessage(WCEnvelope.encode(.generateRequest, request), replyHandler: nil) { [weak self] error in
            Task { @MainActor in
                self?.onError?(
                    GenerationError(requestID: request.requestID, threadID: request.threadID, message: error.localizedDescription)
                )
            }
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let kind = WCEnvelope.kind(of: message) else { return }

        Task { @MainActor in
            switch kind {
            case .tokenChunk:
                if let chunk = WCEnvelope.decode(TokenChunk.self, from: message) {
                    self.onChunk?(chunk)
                }
            case .generationDone:
                if let done = WCEnvelope.decode(GenerationDone.self, from: message) {
                    self.onDone?(done)
                }
            case .generationError:
                if let err = WCEnvelope.decode(GenerationError.self, from: message) {
                    self.onError?(err)
                }
            case .modelStatus:
                if let status = WCEnvelope.decode(ModelStatusUpdate.self, from: message) {
                    self.modelStatus = status
                }
            case .generateRequest:
                break // not expected on the Watch side
            }
        }
    }
}
