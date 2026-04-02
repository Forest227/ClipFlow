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

Current MVP captures text and image clipboard content.

## iCloud Sync

ClipFlow now includes an optional iCloud history sync mode for regular text and image items. Protected items still remain local-only by design.

To actually use iCloud sync on a packaged app, the build must be signed with an Apple Developer identity and iCloud capability enabled for the app identifier. The local ad-hoc build produced by `./scripts/build_app.sh` will compile and run, but iCloud sync may show as unavailable until the app is signed with the proper entitlement setup.

## Files

- `Sources/ClipFlowApp`: SwiftUI prototype
- `docs/clipflow-design.md`: product vision, IA, interaction model, privacy, and roadmap
