import SwiftUI

/// This is the only screen the iPhone app has. There's nothing to interact
/// with day-to-day — the app just needs to stay installed and reasonably
/// nearby so it can host the model for the Watch app. See README for why
/// there's no full chat UI here (that was an explicit v1 scope choice).
struct StatusView: View {
    @Environment(PhoneSessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("WatchAI")
                .font(.title2.bold())

            Text("This app runs the AI model in the background for your Apple Watch. Keep it installed and your phone nearby — chat happens on the Watch.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            statusCard

            HStack(spacing: 6) {
                Circle()
                    .fill(sessionManager.isReachable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(sessionManager.isReachable ? "Watch connected" : "Watch not reachable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(spacing: 8) {
            switch sessionManager.modelStatus.status {
            case .notDownloaded:
                Label("Model not downloaded yet", systemImage: "arrow.down.circle")
            case .downloading:
                ProgressView(value: sessionManager.modelStatus.progress) {
                    Text(sessionManager.modelStatus.detail)
                }
                .progressViewStyle(.linear)
            case .loading:
                ProgressView(sessionManager.modelStatus.detail)
            case .ready:
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Label(sessionManager.modelStatus.detail, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
