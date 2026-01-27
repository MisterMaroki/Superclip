//
//  RichTextEditorPanel.swift
//  Superclip
//

import AppKit
import SwiftUI

class RichTextEditorPanel: NSPanel {
    weak var appDelegate: AppDelegate?
    let item: ClipboardItem
    let clipboardManager: ClipboardManager
    var onSave: ((NSAttributedString) -> Void)?
    var onCancel: (() -> Void)?
    private var localKeyMonitor: Any?

    init(item: ClipboardItem, clipboardManager: ClipboardManager, frame: NSRect) {
        self.item = item
        self.clipboardManager = clipboardManager

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        setupWindow()
        setupContentView()
        setupKeyMonitor()
    }

    deinit {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private func setupWindow() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary
        ]
    }

    private func setupContentView() {
        let editorView = RichTextEditorView(
            item: item,
            clipboardManager: clipboardManager,
            onSave: { [weak self] attributedString in
                self?.onSave?(attributedString)
                self?.closePanel()
            },
            onCancel: { [weak self] in
                self?.onCancel?()
                self?.closePanel()
            }
        )

        let hostingView = NSHostingView(rootView: editorView)
        self.contentView = hostingView
    }

    private func setupKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isKeyWindow else { return event }

            // Escape key - cancel
            if event.keyCode == 53 {
                self.onCancel?()
                self.closePanel()
                return nil
            }

            // Cmd+Enter or Cmd+S - save
            if event.modifierFlags.contains(.command) {
                if event.keyCode == 36 || event.keyCode == 1 { // Enter or S
                    // Trigger save via notification
                    NotificationCenter.default.post(name: .richTextEditorSave, object: self)
                    return nil
                }
            }

            return event
        }
    }

    private func closePanel() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        appDelegate?.removeRichTextEditorWindow(self)
        close()
    }

    /// Find and focus the NSTextView within the hosting view hierarchy
    func focusTextView() {
        guard let hostingView = contentView else { return }
        if let textView = findTextView(in: hostingView) {
            makeFirstResponder(textView)
        }
    }

    private func findTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }
        for subview in view.subviews {
            if let found = findTextView(in: subview) {
                return found
            }
        }
        return nil
    }
}

extension Notification.Name {
    static let richTextEditorSave = Notification.Name("richTextEditorSave")
}
