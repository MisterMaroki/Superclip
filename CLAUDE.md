# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Superclip is a native macOS menu-bar clipboard manager built with SwiftUI and AppKit. It runs as an accessory app (no Dock icon) and is activated via global hotkeys.

**Global Hotkeys:**

- `Cmd+Shift+A` - Open clipboard history drawer
- `Cmd+C` - Copy to clipboard (standard)
- `Cmd+Shift+C` - Copy and open in paste stack
- `Cmd+V` - Simulated paste (used by paste stack)

## Architecture

### Key Components

**AppDelegate** (`AppDelegate.swift`) - Central coordinator:

- Window lifecycle (ContentPanel, PreviewPanel, RichTextEditorPanel)
- Global hotkey registration via HotKey
- Global event monitors for clicks/keys and paste simulation
- Entry points for automation hooks (open panels, seed clipboard)

**ClipboardManager** (`ClipboardManager.swift`) - Core clipboard functionality:

- Polls `NSPasteboard` every 0.5s
- Detects: images, files, URLs, plain text, RTF
- Maintains history (max 100) with deduplication
- Stores source app metadata
- Undo window for deletions (~30s)
- Link metadata fetching (title, description, favicon)

**NavigationState** (`NavigationState.swift`) - Keyboard navigation:

- Arrow keys to navigate items; Enter to select
- Cmd+Arrow keys to navigate pinboards
- Space to open preview; hold Space to open editor
- Backspace/Delete to remove; Cmd+Z to undo
- Typing any character enters search
- Esc clears search / closes panels

**PasteStackManager** (`PasteStackManager.swift`) - Sequential paste:

- Session-scoped stack of captured items
- Auto-advance after each simulated paste (`Cmd+V`)
- Actions: copy item, paste current, remove item

**PinboardManager** (`PinboardManager.swift`) - Favorites:

- Pin/unpin items; persisted across launches
- Quick access UI and navigation

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

### Content Detection Order

1. Images
2. Files (special-case single-image files)
3. URLs (with metadata)
4. Plain text

## Dependencies

Managed via Swift Package Manager:

- **HotKey** - Global keyboard shortcuts

## Key Patterns & Conventions

- Use `[weak self]` in closures to avoid retain cycles
- Invalidate timers and remove observers in `deinit`
- Use `@MainActor` / `DispatchQueue.main.async` for UI updates
- Prefer actors for shared mutable state where appropriate
- Use `NSHostingView` to embed SwiftUI in AppKit panels
- Wrap `NSTextView` with `NSViewRepresentable` for rich editing

## Automation Hooks & Targets

- Build & archive + notarize pipeline
- CI: linting (SwiftLint), formatting (swift-format), unit tests
- Export/import: pins, history, preferences
- App Store packaging: screenshots, metadata, upload helper
- Developer helpers: seed clipboard, open panels, toggle feature flags
