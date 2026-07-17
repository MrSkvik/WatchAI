# WatchAI

A Claude/Gemini-style AI chat app for Apple Watch. The Watch app is the chat
UI (thread list, message bubbles, dictation input, streamed replies); your
iPhone runs the actual model on-device via [MLX](https://github.com/ml-explore/mlx-swift-lm)
and streams tokens back over WatchConnectivity. No server, no API key, no
cloud calls — everything happens on your own two devices.

Model: **Gemma 4 E2B** (4-bit quantized, Apache 2.0, ~3.55GB download),
Google's smallest Gemma 4 variant, chosen to fit an 8GB-RAM iPhone. See
[Model choice](#model-choice) below if you want to change it.

## Architecture

```
 Apple Watch (SwiftUI + SwiftData)          iPhone (SwiftUI, background)
 ┌─────────────────────────────┐            ┌──────────────────────────┐
 │ ThreadListView / ChatView    │            │ StatusView (nothing to   │
 │  - owns all chat history      │  Watch     │  do here day-to-day)     │
 │  - dictation / Scribble input │Connectivity│                          │
 │ WatchSessionManager  ───────────────────────► PhoneSessionManager     │
 │  (sends GenerateRequest,      │  messages  │  (receives request,      │
 │   receives streamed chunks)   │◄───────────────  drives ModelEngine)  │
 └─────────────────────────────┘            │           │               │
                                             │           ▼               │
                                             │      MLX ChatSession      │
                                             │   (Gemma 4 E2B, 4-bit)    │
                                             └──────────────────────────┘
```

Why this shape: an Apple Watch has nowhere near enough RAM/compute to run an
LLM, and MLX (Apple's on-device ML framework) doesn't even target watchOS —
only iOS/macOS/tvOS/visionOS. So the iPhone does the thinking, and the Watch
is a thin, fast chat client, same as how the mainstream apps *feel* even
though under the hood they're calling a cloud API instead of your pocket.

## One-time setup

### 1. Install Xcode

This Mac currently only has the Command Line Tools, not the full Xcode.app
— `xcodebuild` needs full Xcode for the iOS/watchOS SDKs, simulators, and
on-device signing. Install it from the **App Store** (search "Xcode", ~15GB,
free) or [developer.apple.com/download](https://developer.apple.com/download/).
After it installs, run:

```sh
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -license accept
```

### 2. Open the project

The project is already generated at `~/Developer/WatchAI/WatchAI.xcodeproj`
using [XcodeGen](https://github.com/yonaskolb/XcodeGen) (already installed
via Homebrew). Open it:

```sh
open ~/Developer/WatchAI/WatchAI.xcodeproj
```

If you ever edit `project.yml` (e.g. to change the model or bundle ID),
regenerate with:

```sh
cd ~/Developer/WatchAI && xcodegen generate
```

### 3. Resolve the MLX package

Xcode should resolve `mlx-swift-lm` automatically on first open (File →
Packages → Resolve Package Versions if not). This pulls in MLXLLM,
MLXLMCommon, and MLXHuggingFace.

### 4. Sign with your free Apple ID

You said you don't have a paid Developer account ($99/yr), so:

1. Xcode → Settings → Accounts → add your Apple ID.
2. Select each target (**WatchAI**, **WatchAI Watch App**, **WatchAI
   Complication**) → Signing & Capabilities → set **Team** to your personal
   team.
3. Build and run to your iPhone, then to your paired Watch.

**Free-account limitation:** apps installed this way stop launching after
**7 days** and need to be rebuilt from Xcode (Product → Run) to keep working
— there's no way around this without the paid account. If this becomes
annoying, the $99/yr account removes the limit entirely and is the only real
fix.

### 5. Run it

- Build/run the **WatchAI** scheme with your iPhone selected as the
  destination first (installs both the iPhone app and, via Watch pairing,
  offers to install the Watch app too — accept it, or install the Watch App
  scheme directly to your Watch).
- Open the iPhone app once and leave it installed — first launch starts
  downloading Gemma 4 E2B (~3.55GB, needs Wi-Fi, takes a few minutes).
  You'll see progress on the iPhone's status screen.
- Once it shows "Model ready", open WatchAI on your Watch, tap **+** for a
  new chat, and start typing (dictation/Scribble) or type on the paired
  simulator keyboard if testing there.

## Model choice

`LLMRegistry.gemma4_e2b_it_4bit` is set in
[`iOS/ModelEngine.swift`](iOS/ModelEngine.swift). If it's too slow or too
much memory pressure on your phone in practice, swap to a smaller model —
e.g. `LLMRegistry.gemma3_1B_qat_4bit` — by editing that one line. Any model
in [`mlx-community`](https://huggingface.co/mlx-community) works; you can
also reference one directly by Hugging Face id without a registry constant.

## Known v1 limitations

These were deliberate scope cuts to get a working app fast, not oversights —
worth knowing about, easy to revisit later:

- **iPhone must be nearby and unlocked while chatting.** WatchConnectivity's
  real-time messaging (`sendMessage`) requires the counterpart app to be
  reachable; this doesn't wake a locked/backgrounded iPhone. Fine for the
  normal "glance at your watch, iPhone's in your pocket" use case.
- **No cross-restart model context.** Each thread's conversation memory
  lives in the iPhone app's process. If iOS kills/restarts the app, the next
  message in an old thread starts the model fresh (your Watch-side message
  history is untouched — just the model's short-term memory of earlier
  turns in that thread).
- **iPhone app has no real UI**, by design (your choice) — it's just a
  status screen showing model/connection state.
- **No persona/system-prompt customization yet** — the system prompt is
  hardcoded in `ModelEngine.swift`.
- **Complication is static** — a tap-to-launch icon, no live data on the
  watch face.

## First-build caveat

I wrote every file against the current (July 2026) `mlx-swift-lm` API,
verified line-by-line against Apple's own example app
(`mlx-swift-examples/Applications/LLMBasic`) — but I have no way to run
`xcodebuild` on this machine (no full Xcode yet), so nothing here has
actually compiled. Once you've installed Xcode, if the first build throws
errors, paste them back to me here and I'll fix them directly — bleeding-edge
SPM packages like this one do shift their API occasionally.
