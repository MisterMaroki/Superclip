# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Superclip is a native macOS menu bar clipboard manager built with SwiftUI. It runs as an accessory app (no dock icon) and is activated via global hotkeys.

**Global Hotkeys:**

- `Cmd+Shift+A` - Open clipboard history drawer
- `Cmd+Shift+C` - Open paste stack (sequential pasting mode)

## Architecture

### Key Components

**AppDelegate** (`AppDelegate.swift`) - Central coordinator managing:

- Window lifecycle (ContentPanel, PreviewPanel, RichTextEditorPanel)
- Global hotkey registration via HotKey package
- System-wide click/key event monitoring
- Clipboard item selection and paste simulation

**ClipboardManager** (`ClipboardManager.swift`) - Core clipboard functionality:

- Polls system pasteboard every 0.5 seconds
- Detects text, images, files, and URLs
- Maintains history (max 100 items) with deduplication
- Supports undo (30-second window) and link metadata fetching

**NavigationState** (`NavigationState.swift`) - Keyboard navigation state:

- Arrow keys to navigate, Enter to select, Space for preview
- Backspace to delete, Cmd+Z to undo, "/" to search

**PasteStackManager** (`PasteStackManager.swift`) - Sequential paste workflow:

- Tracks items copied during session
- Auto-advances after each Cmd+V paste

### Window System

All windows are `NSPanel` subclasses with `borderless` + `nonactivatingPanel` style masks:

- **ContentPanel** - Main drawer at screen bottom (280px height)
- **PreviewPanel** - Floating preview above selected card
- **RichTextEditorPanel** - Standalone editor windows (no title bar)

Panels use `floatingLevel` and `canJoinAllSpaces` for cross-space visibility.

### Data Model

`ClipboardItem` struct stores:

- `content: String` - Plain text content
- `rtfData: Data?` - Rich text formatting (RTF)
- `imageData: Data?` - Image data for image items
- `fileURLs: [URL]?` - File references
- `linkMetadata: LinkMetadata?` - Cached URL preview data
- `sourceApp: SourceApp?` - App that originated the copy

### Content Type Detection Order

1. Images (PNG/TIFF data)
2. Files (with special handling for single image files)
3. URLs (with metadata fetching)
4. Plain text (with URL detection from strings)

## Dependencies

Single external dependency managed via Swift Package Manager:

- **HotKey** (https://github.com/soffes/HotKey) - Global keyboard shortcut support

## Key Patterns

- Use `[weak self]` in all closures to prevent retain cycles
- Invalidate timers in `deinit`
- Use `DispatchQueue.main.async` for UI updates from clipboard monitoring
- Panels use `NSHostingView` to bridge SwiftUI views into AppKit windows
- `NSViewRepresentable` wraps AppKit views (NSTextView) for rich text editing
