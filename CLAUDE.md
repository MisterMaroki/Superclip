# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Superclip is a native macOS menu-bar clipboard manager built with SwiftUI and AppKit. It runs as an accessory app (no Dock icon) and is activated via global hotkeys.

**Global Hotkeys:**

- `Cmd+Shift+A` - Open clipboard history drawer
- `Cmd+Shift+C` - Open paste stack (copies made while it is open are queued)
- `Cmd+Shift+4` - Screenshot (area / window / full screen picker)
- `Cmd+Shift+3` - Capture the full screen immediately
- `` Cmd+Shift+` `` - Text Sniper (OCR a screen region)
- `Cmd+V` - Simulated paste (drawer selection, paste stack)

All are rebindable in Settings > Shortcuts. macOS reserves `Cmd+Shift+3/4` for its own screenshots unless the user turns those off.

## Architecture

### Key Components

**AppDelegate** (`AppDelegate.swift`) - Central coordinator:

- Window lifecycle (ContentPanel, PreviewPanel, RichTextEditorPanel)
- Global hotkey registration via HotKey
- Global event monitors for clicks/keys and paste simulation
- Entry points for automation hooks (open panels, seed clipboard)

**ClipboardManager** (`ClipboardManager.swift`) - Core clipboard functionality:

- Polls `NSPasteboard` every 0.5s (0.12s while a paste stack session is open)
- Detects: images, files, URLs, plain text (RTF is only stored for clips edited in the rich text editor)
- Text is stored exactly as copied (no trimming)
- History with deduplication; size limit is a setting (default unlimited)
- `captured` subject emits real user copies only; `history` also changes on reorder/edit
- `historyVersion` lets views cache work derived from history
- Stores source app metadata
- Undo window for deletions (~30s)
- Link metadata fetching (title, description, favicon), persisted with history
- Clearing history keeps pinned items; `clearHistory(includingPinned:)` wipes everything

**NavigationState** (`NavigationState.swift`) - Keyboard navigation:

- Arrow keys to navigate items; Enter to paste; Shift+Enter to paste as plain text
- Cmd+C copies the selected item without closing the drawer
- Cmd+Arrow keys to navigate pinboards; Cmd+1-9/0 quick paste
- Space to open preview; hold Space to open editor
- Backspace/Delete to remove (inside a pinboard it unpins instead); Cmd+Z to undo
- Typing any character enters search; type filter pills appear while searching
- Esc clears search / closes panels
- Hold-to-edit progress lives in its own `HoldProgress` object so the 60Hz updates don't re-render the drawer

**PasteStackManager** (`PasteStackManager.swift`) - Sequential paste:

- Session-scoped queue of items copied while the stack is open
- Subscribes to `ClipboardManager.captured`, never to `history` (reacting to its own pasteboard writes was the old "wrong item pasted" bug)
- Keeps the queue head on the pasteboard; advances after each user `Cmd+V`
- `newestFirst` switches paste order; clicking a row pastes that row (`prepareToPaste`)
- The panel never becomes key, so the user's app stays the paste target

**PinboardManager** (`PinboardManager.swift`) - Favorites:

- Pin/unpin items; persisted across launches
- Quick access UI and navigation

**SnippetManager** (`SnippetManager.swift`) - Text expansion:

- Trigger-based snippets (e.g., `;;email` expands to full text)
- Global keyboard monitor detects triggers in any app
- CRUD with enable/disable; persisted via UserDefaults

**QuickActions** (`QuickActions.swift`) - Context-aware actions:

- `QuickActionAnalyzer` detects content types (color hex/rgb/hsl, JSON, email, phone, code, file path)
- `QuickActionsProvider` maps detections to actionable conversions (e.g., hex → RGB, JSON → pretty print)
- `QuickActionsBar` displayed in preview panel with color swatch

**ContentDetector** (`ContentDetector.swift`) - Auto-tagging:

- Regex-based detection of colors, emails, phones, code, JSON, addresses
- Tags stored as `Set<ContentTag>` on each `ClipboardItem`
- Powers smart filter bar and card content badges
- `singleColor(in:)` identifies clips that are exactly one colour value (these get a solid colour card)
- Runs on the main thread at copy time: keep every pattern bounded (an unbounded one froze the app on a pasted column of numbers) and scan a capped prefix

**FuzzySearch** (`FuzzySearch.swift`) - Ranked search:

- Scoring: exact > prefix > contains > fuzzy subsequence
- Matches on content, source app, type label, file names

**OCRManager** (`OCRManager.swift`) - OCR support:

- Extract text from images/screenshots
- Actions: copy OCR result, open in editor

**ImageEditorView / ScreenCaptureView** - Image workflows:

- Image editing (crop, annotate), save, copy
- Screen capture integration and editing pipeline

### Window System

All windows are `NSPanel` subclasses with `borderless` + `nonactivatingPanel` style masks:

- **ContentPanel** - Main drawer at screen bottom
- **PreviewPanel** - Floating preview above selected card
- **RichTextEditorPanel** - Standalone editor window

Panels use `floatingLevel` and `canJoinAllSpaces`.

### Data Model

`ClipboardItem` includes:

- `content: String`
- `rtfData: Data?`
- `imageData: Data?`
- `fileURLs: [URL]?`
- `linkMetadata: LinkMetadata?`
- `sourceApp: SourceApp?`
- `detectedTags: Set<ContentTag>` — auto-detected content sub-categories

### Content Detection Order

1. Images
2. Files (special-case single-image files)
3. URLs (with metadata)
4. Plain text

**DataArchive** (`DataArchive.swift`) - Export / import:

- One JSON file with history, images, rich text, pinboards and snippets
- Import merges; it never replaces or deletes existing data

## Dependencies

Managed via Swift Package Manager:

- **HotKey** - Global keyboard shortcuts

## Key Patterns & Conventions

- `Brand.white` / `Brand.black` / `Brand.grayN` are **adaptive**: they flip in dark mode. Pair them with each other on app chrome. On a fixed backdrop (a scrim, an image, the screen, a coloured fill) use literal `Color.white` / `Color.black`, and never put `.primary` text on a fixed dark or coloured background
- Use `[weak self]` in closures to avoid retain cycles
- Invalidate timers and remove observers in `deinit`
- Use `@MainActor` / `DispatchQueue.main.async` for UI updates
- Prefer actors for shared mutable state where appropriate
- Use `NSHostingView` to embed SwiftUI in AppKit panels
- Wrap `NSTextView` with `NSViewRepresentable` for rich editing

## Design language ("Ink")

Shared by the Mac and iPhone apps: paper and ink neutrals, square geometry (no rounded corners on our own chrome), a 2pt rule in the content type's colour at the top of each card, small mono capitals for labels and metadata, and ink-filled selection. Colour is spent on content, never on chrome. System-drawn chrome (the iOS tab bar, menus, sheets' grabbers) is left to the platform.

- Mac tokens: `BrandColors.swift`. Square switch: `BrandSwitchStyle`. Drawer key hints: `KeyHintBar`.
- iPhone tokens and controls: `SuperclipiOS/Sources/Design/Ink.swift`.

## iPhone app (`SuperclipiOS/`)

SwiftUI, iOS 17+. The Xcode project is generated: run `xcodegen generate` in `SuperclipiOS/` after adding or removing files.

- `Model/Clip.swift` - platform-neutral `Clip`, `Pinboard`, `Snippet`; `ClipClassifier` decides text / link / color / code
- `Model/ClipStore.swift` - single source of truth, persisted as JSON plus an images folder; every mutation goes through it (this is where sync will attach)
- `Screens/` - `HistoryScreen` (tap to copy, swipe to pin or delete, bottom search), `ClipDetailSheet`, `PinboardsScreen`, `SnippetsScreen`, `SettingsSheet`
- Reading the clipboard goes through the system `PasteButton`, so iOS never shows its "Allow Paste" alert
- Launch arguments for review: `-sampleData 1`, `-appearance dark|light`, `-screen pinboards|snippets|detail|settings|search`
- Share extension (`ShareExtension/`): writes shared text, links and images to `SharedInbox` in the app group; the app imports them when it comes to the front

## iCloud sync

Both apps sync clips, pinboards and snippets through the user's private CloudKit database. Setup steps the developer account needs are in `SYNC_SETUP.md`; until they are done sync reports itself unavailable and nothing else changes.

- `Superclip/Sync/` is compiled into both apps (the iPhone project references the folder). Keep it free of AppKit and UIKit.
  - `SyncModels.swift` - `SyncClip`, `SyncPinboard`, `SyncSnippet`, `SyncKey`, `SyncPolicy` (30-day retention, 10 MB image cap)
  - `SyncMerge.swift` - pure merge rules (later edit wins, cross-device duplicate resolution, three-way pin-list merge) and `SyncChangeTracker`
  - `CloudSyncEngine.swift` - the only code that touches CloudKit; wraps `CKSyncEngine`; talks to the app through `CloudSyncStore`
  - `CloudRecordCoding.swift` - models to `CKRecord` and back; user content goes in encrypted fields
- Adapters: `MacSyncCoordinator.swift` (Mac; off by default, Settings > General) and `SuperclipiOS/Sources/Sync/PhoneSync.swift` (iPhone; on by default)
- Local stores stay the source of truth. A clip trimmed from history locally is not deleted from iCloud; only explicit user deletions are sent.
- Copied files never sync (a path means nothing on another device).

## Testing

There is no XCTest target. Two scripts compile the app's sources into small executables that run against a private pasteboard and a scratch home directory (never real data):

- `scripts/tests/run.sh` - logic tests (capture, paste stack, clearing, editing, search, export/import) and content-detector tests
- `scripts/render-screens/run.sh [scene,scene]` - renders the main screens in light and dark to `build/screens/` for a visual check

## Automation Hooks & Targets

- Build & archive + notarize pipeline
- CI: linting (SwiftLint), formatting (swift-format), unit tests
- Export/import: pins, history, preferences
- App Store packaging: screenshots, metadata, upload helper
- Developer helpers: seed clipboard, open panels, toggle feature flags
