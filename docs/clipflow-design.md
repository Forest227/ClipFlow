# ClipFlow Design Spec

## Product Thesis

ClipFlow is a pointer-first clipboard companion for macOS. It should feel lighter than opening a manager window, safer than keeping raw history forever, and faster than manually hunting for the last copied item.

The core promise:

- Summon near the pointer
- Paste in one move
- Group content intelligently
- Respect privacy by default
- Behave like a native system utility, not a detached dashboard

## Target Users

- Developers juggling code, commands, links, and tokens
- Designers moving assets, text snippets, and references across apps
- Researchers and operators curating repetitive fragments all day
- Privacy-conscious users who want history without surveillance vibes

## Experience Principles

### 1. Pointer-first, not window-first

The fastest path should not require leaving the current context. Global invoke opens a compact HUD anchored near the pointer, with the most likely next paste already highlighted.

### 2. Retrieval should beat recall

Users should not need to remember exact text. Cards use app source, semantic labels, recency, privacy state, and short summaries to make visual scanning immediate.

### 3. Intelligence must stay legible

Smart grouping is useful only if it remains predictable. ClipFlow should explain why something is grouped as code, link, finance, credential, image, or temporary secret.

### 4. Privacy is an interaction feature

Privacy should not live only in settings. Masked previews, protected lanes, local-only badges, pause capture, exclusion rules, and auto-expiry need to be visible in day-to-day flows.

### 5. Native integration over feature sprawl

ClipFlow wins by fitting into macOS patterns: menu bar access, global shortcut, Services, Quick Look style preview, drag and drop, login item support, Shortcuts integration, and polished window behavior.

## Information Architecture

ClipFlow has five primary surfaces:

1. Pointer HUD
   - Compact launcher near cursor
   - Top suggestions and one-keystroke paste
   - Search, filter, and protected item reveal

2. Main Library
   - Three-column layout
   - Left: smart collections and privacy controls
   - Center: clipboard timeline and suggested stacks
   - Right: detail preview, paste targets, and protection state

3. Menu Bar Presence
   - Immediate access to recent items
   - Capture pause, current status, and secure mode visibility

4. Privacy Settings
   - Excluded apps
   - Auto-expire rules
   - Local-only capture
   - Redaction and masked previews

5. Secure Vault Lane
   - Passwords, codes, or sensitive data
   - Separate reveal interaction
   - Optional shorter retention windows

## Core Flows

## Flow A: Quick paste near pointer

1. User copies content in any app
2. ClipFlow classifies the content locally
3. User invokes ClipFlow with a global shortcut
4. HUD opens near pointer, not centered on screen
5. Best match is preselected and can be pasted immediately
6. Arrow keys or search narrow the list without losing pointer context

Success metric: one invoke, one confirm, one paste

## Flow B: Browse and recover older context

1. User opens the main library from the menu bar or shortcut
2. Smart collections separate code, links, files, protected items, and pinned snippets
3. Rich cards display source app, labels, time, and privacy state
4. Detail pane supports inspection before paste or share

Success metric: find older content in under five seconds

## Flow C: Protect sensitive snippets

1. ClipFlow detects credentials, codes, finance, or secret-like patterns
2. Item is routed into the protected lane with masked preview
3. User can choose local-only, auto-expire, or never save
4. Sensitive apps can be excluded entirely from capture

Success metric: privacy state is obvious at glance and reversible

## Visual Direction

ClipFlow should feel calm, precise, and premium:

- Base tone: warm paper and frosted glass, not sterile white
- Accent palette: copper, saffron, and lake blue
- Shape language: rounded rectangles, floating panels, subtle depth
- Typography: native SF with generous weight contrast and spacious line height
- Motion: quick spring transitions around 220-260 ms, with panels feeling attached to pointer movement

The UI should avoid looking like a generic admin tool. Clipboard history is a high-frequency surface; density matters, but each layer should still feel breathable.

## Key UI Components

### Pointer HUD

- Small floating panel with strong focus ring
- Search field always available
- Top result with semantic badge and paste target hints
- Reveal control for protected entries
- Keyboard-first navigation

### Clipboard Card

- Source app identity
- Item kind badge
- Time stamp
- Snippet preview
- Smart labels
- Privacy state chip
- Primary action: Paste

### Detail Preview

- Large readable preview
- Context summary explaining grouping
- Paste target suggestions
- Retention and privacy controls
- Quick actions: pin, copy again, reveal, purge

### Collection Rail

- All items
- Quick paste
- Smart stacks
- Code
- Links
- Files
- Protected

## Privacy Model

Privacy must be layered:

- Default local processing for classification
- App exclusion list for banking, password managers, terminals, or custom apps
- Temporary pause capture from menu bar or HUD
- Separate protected lane with masked previews
- Auto-expire timers for secrets and one-time codes
- Manual purge of single items or time ranges
- Clear indicators for local-only items and unsynced storage

## System Integration

ClipFlow should integrate with the platform through:

- `NSPasteboard` for capture and restore
- Menu bar extra for status and fast access
- Global shortcut for invoke
- Accessibility APIs to anchor HUD near pointer and active UI context
- Login item support
- Shortcuts and Services for automation
- Drag and drop to apps and Finder
- Quick Look style inspection for files and images

## Suggested Technical Architecture

- SwiftUI for app shell and native panel composition
- AppKit bridges for global hotkey, menu bar behavior, pointer anchoring, and pasteboard hooks
- Local store for metadata, retention, and protected flags
- On-device classifiers for semantic grouping
- Rules engine for exclusions, expiry, and confidence thresholds

## MVP Scope

- Clipboard capture timeline
- Pointer HUD invoke
- Smart collections
- Search
- Pinned items
- Protected lane with masked previews
- Menu bar extra
- Excluded app list

## V2 Expansion

- OCR for copied images
- Named stacks and project contexts
- Cross-device sync with explicit trust model
- Team snippet handoff
- AI-assisted rewrite or summarization before paste

## Prototype Mapping

The SwiftUI prototype in this repo visualizes:

- A premium native desktop layout
- Pointer HUD concept
- Collection rail and timeline cards
- Detail preview with paste actions
- Privacy surface and system integration concepts

It is intentionally a concept prototype, not a full clipboard daemon.
