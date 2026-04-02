# ClipFlow

ClipFlow is a macOS clipboard concept app focused on pointer-first invocation, instant paste, smart grouping, privacy defaults, and deep system integration.

This repository includes:

- A native SwiftUI concept prototype
- A functional initial clipboard app shell with live capture, menu bar access, quick-paste HUD, and privacy heuristics
- A product and UX design spec for the app direction

## Run

```bash
swift build
swift run ClipFlowApp
```

## Build Local `.app`

```bash
./scripts/build_app.sh
open dist/ClipFlow.app
```

For one-tap paste into other apps, macOS will ask for Accessibility permission the first time ClipFlow tries to send `Command + V`.

Current MVP captures text clipboard content. Images, files, and richer pasteboard payloads are good next steps.

## Files

- `Sources/ClipFlowApp`: SwiftUI prototype
- `docs/clipflow-design.md`: product vision, IA, interaction model, privacy, and roadmap
