# Superclip

An open source macOS clipboard manager designed to replace the 'Paste' app.

## What is Superclip?

Superclip is a lightweight, native macOS clipboard manager that runs from your menu bar. It provides quick access to your clipboard history, allowing you to easily browse and paste previously copied items.

## Features

- **Clipboard history** — everything you copy, saved and searchable with fuzzy matching
- **Pinboards** — color-coded collections for frequently used items
- **Snippets** — define trigger shortcuts (e.g., `;;email`) that expand into full text in any app
- **Quick Actions** — context-aware actions per content type: convert colors between hex/RGB/HSL, pretty print JSON, compose emails, reveal file paths
- **Smart Filters** — auto-tags content (colors, code, emails, JSON, phone numbers) and lets you filter by type
- **Paste Stack** — copy multiple items, paste them in sequence with auto-advance
- **Built-in OCR** — extract text from images and screen regions
- **Keyboard-first** — global hotkeys, arrow navigation, type-to-search
- **Private by default** — everything stays on your Mac, no cloud sync, no tracking
- **Native macOS** — built with SwiftUI, launches in 0.3s, uses less than 30MB RAM

## Requirements

- macOS (requires Accessibility permissions for global hotkey support)

## Installation

1. Clone this repository
2. Open `Superclip.xcodeproj` in Xcode
3. Build and run the project

## Usage

After launching Superclip, it will run in the background. Press `⌘⇧A` (Command + Shift + A) to open the clipboard manager window and browse your clipboard history.

## License

[Add your license here]
