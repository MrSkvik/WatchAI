import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

/// Gemma 4 E2B, 4-bit quantized (~3.55GB download) — Google's smallest Gemma 4
/// variant, sized to fit comfortably on an 8GB-RAM iPhone (15 Pro/16/16 Pro+).
/// If this proves too tight in practice, swap for a smaller registry entry
/// such as `LLMRegistry.gemma3_1B_qat_4bit`.
private let modelConfiguration = LLMRegistry.gemma4_e2b_it_4bit

private let systemInstructions = """
    You are a helpful, concise AI assistant. The user is talking to you through \
    an Apple Watch app, so keep replies short and to the point — a few sentences \
    at most unless they explicitly ask for more detail.
    """

/// Owns the on-device model and one `ChatSession` per open thread. Runs on
/// the main actor, mirroring Apple's own MLX Swift example apps (ModelLoader /
/// ChatModel in mlx-swift-examples/Applications/LLMBasic).
@MainActor
final class ModelEngine {
    private var container: ModelContainer?
    private var loadTask: Task<ModelContainer, Error>?
    private var sessions: [UUID: ChatSession] = [:]

    /// Downloads (first run only) and loads the model, reporting progress.
    /// Safe to call repeatedly — subsequent calls await the same in-flight
    /// task or return the already-loaded container immediately.
    @discardableResult
    func ensureLoaded(statusHandler: @escaping (ModelStatusUpdate) -> Void) async throws -> ModelContainer {
        if let container {
            return container
        }
        if let loadTask {
            return try await loadTask.value
        }

        statusHandler(.init(status: .downloading, progress: 0, detail: "Downloading Gemma 4 E2B…"))

        let task = Task<ModelContainer, Error> {
            try await #huggingFaceLoadModelContainer(configuration: modelConfiguration) { progress in
                Task { @MainActor in
                    statusHandler(
                        .init(
                            status: .downloading,
                            progress: progress.fractionCompleted,
                            detail: "Downloading Gemma 4 E2B…"))
                }
            }
        }
        loadTask = task

        do {
            let model = try await task.value
            container = model
            loadTask = nil
            statusHandler(.init(status: .ready, progress: 1, detail: "Model ready"))
            return model
        } catch {
            loadTask = nil
            statusHandler(.init(status: .failed, progress: 0, detail: error.localizedDescription))
            throw error
        }
    }

    /// Streams a response for `userText` in the context of `threadID`.
    ///
    /// Each thread gets one long-lived `ChatSession` that keeps its own KV
    /// cache, so only the *new* user message is sent per turn — the session
    /// remembers prior turns on its own. Note: if this app process is
    /// terminated and relaunched, in-memory sessions are lost and a thread's
    /// conversation restarts fresh on the model side (the Watch still shows
    /// full history, only the model's short-term context is affected).
    func streamResponse(
        threadID: UUID,
        userText: String,
        statusHandler: @escaping (ModelStatusUpdate) -> Void
    ) async throws -> AsyncThrowingStream<String, Error> {
        let model = try await ensureLoaded(statusHandler: statusHandler)

        let session = sessions[threadID] ?? ChatSession(
            model,
            instructions: systemInstructions,
            generateParameters: GenerateParameters(temperature: 0.6)
        )
        sessions[threadID] = session

        return session.streamResponse(to: userText)
    }
}
