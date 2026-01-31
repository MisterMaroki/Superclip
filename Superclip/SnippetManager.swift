//
//  SnippetManager.swift
//  Superclip
//

import Foundation
import AppKit
import Combine

/// A text snippet with a trigger shortcut for text expansion.
struct Snippet: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var trigger: String      // e.g., ";;email"
    var content: String      // The expanded text
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, trigger: String, content: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.content = content
        self.isEnabled = isEnabled
    }
}

/// Manages text snippets and monitors keyboard for trigger expansion.
class SnippetManager: ObservableObject {
    @Published var snippets: [Snippet] = []

    private let storageKey = "SuperclipSnippets"
    private let storage = UserDefaults.standard

    /// Buffer of recently typed characters for trigger detection.
    private var typeBuffer: String = ""
    private let maxBufferLength = 50
    private var keyMonitor: Any?

    init() {
        loadSnippets()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Persistence

    private func loadSnippets() {
        guard let data = storage.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Snippet].self, from: data) else {
            snippets = []
            return
        }
        snippets = decoded
    }

    private func saveSnippets() {
        guard let encoded = try? JSONEncoder().encode(snippets) else { return }
        storage.set(encoded, forKey: storageKey)
    }

    // MARK: - CRUD

    @discardableResult
    func createSnippet(name: String, trigger: String, content: String) -> Snippet {
        let snippet = Snippet(name: name, trigger: trigger, content: content)
        snippets.append(snippet)
        saveSnippets()
        return snippet
    }

    func updateSnippet(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
        saveSnippets()
    }

    func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveSnippets()
    }

    func toggleSnippet(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index].isEnabled.toggle()
        saveSnippets()
    }

    // MARK: - Text Expansion Monitoring

    func startMonitoring() {
        guard keyMonitor == nil else { return }

        // Global key monitor to capture keystrokes in any app
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    func stopMonitoring() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let chars = event.characters, !chars.isEmpty else { return }

        // Reset buffer on modifier keys (except Shift which is normal typing)
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option) {
            typeBuffer = ""
            return
        }

        // Append to buffer
        typeBuffer += chars

        // Trim buffer to max length
        if typeBuffer.count > maxBufferLength {
            typeBuffer = String(typeBuffer.suffix(maxBufferLength))
        }

        // Check for backspace (key code 51) — remove last char from buffer
        if event.keyCode == 51 {
            typeBuffer = ""  // Reset on backspace for simplicity
            return
        }

        // Check if buffer ends with any enabled trigger
        for snippet in snippets where snippet.isEnabled {
            if typeBuffer.hasSuffix(snippet.trigger) {
                expandSnippet(snippet)
                typeBuffer = ""
                break
            }
        }
    }

    /// Expand a snippet by deleting the trigger characters and typing the replacement.
    private func expandSnippet(_ snippet: Snippet) {
        let triggerLength = snippet.trigger.count

        // Delete the trigger characters (simulate backspace)
        DispatchQueue.main.async {
            let source = CGEventSource(stateID: .hidSystemState)

            // Delete trigger characters
            for _ in 0..<triggerLength {
                let backspaceDown = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)
                let backspaceUp = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)
                backspaceDown?.post(tap: .cghidEventTap)
                backspaceUp?.post(tap: .cghidEventTap)
            }

            // Small delay to let backspaces process, then paste the content
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // Save current clipboard, replace with snippet, paste, restore
                let pasteboard = NSPasteboard.general
                let savedItems = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
                    var dict = [NSPasteboard.PasteboardType: Data]()
                    for type in item.types {
                        if let data = item.data(forType: type) {
                            dict[type] = data
                        }
                    }
                    return dict.isEmpty ? nil : dict
                }

                // Set snippet content
                pasteboard.clearContents()
                pasteboard.setString(snippet.content, forType: .string)

                // Simulate Cmd+V
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
                keyDown?.flags = .maskCommand
                keyUp?.flags = .maskCommand
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)

                // Restore clipboard after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if let savedItems = savedItems, !savedItems.isEmpty {
                        pasteboard.clearContents()
                        for itemDict in savedItems {
                            let item = NSPasteboardItem()
                            for (type, data) in itemDict {
                                item.setData(data, forType: type)
                            }
                            pasteboard.writeObjects([item])
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Check if a trigger is already used by another snippet.
    func isTriggerTaken(_ trigger: String, excludingId: UUID? = nil) -> Bool {
        snippets.contains { $0.trigger == trigger && $0.id != excludingId }
    }

    var enabledSnippetCount: Int {
        snippets.filter(\.isEnabled).count
    }
}
