//
//  SettingsPanel.swift
//  Superclip
//

import AppKit
import SwiftUI

class SettingsPanel: NSPanel {
    weak var appDelegate: AppDelegate?
    let settings: SettingsManager
    let clipboardManager: ClipboardManager
    let pinboardManager: PinboardManager
    let snippetManager: SnippetManager

    init(settings: SettingsManager, clipboardManager: ClipboardManager, pinboardManager: PinboardManager, snippetManager: SnippetManager) {
        self.settings = settings
        self.clipboardManager = clipboardManager
        self.pinboardManager = pinboardManager
        self.snippetManager = snippetManager

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.borderless, .nonactivatingPanel, .titled],
            backing: .buffered,
            defer: true
        )

        setupWindow()
        setupContentView()
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            appDelegate?.closeSettingsWindow()
        } else if event.keyCode == 13 && event.modifierFlags.contains(.command) { // Cmd+W
            appDelegate?.closeSettingsWindow()
        } else {
            super.keyDown(with: event)
        }
    }

    private func setupWindow() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        animationBehavior = .none

        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
        ]

        hidesOnDeactivate = false
    }

    private func setupContentView() {
        let settingsView = SettingsView(
            onClose: { [weak self] in
                self?.appDelegate?.closeSettingsWindow()
            },
            settings: settings,
            clipboardManager: clipboardManager,
            pinboardManager: pinboardManager,
            snippetManager: snippetManager
        )

        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        self.contentView = hostingView

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth: CGFloat = 680
            let panelHeight: CGFloat = 480

            let xPosition = screenFrame.midX - panelWidth / 2
            let yPosition = screenFrame.midY - panelHeight / 2

            let panelFrame = NSRect(x: xPosition, y: yPosition, width: panelWidth, height: panelHeight)
            setFrame(panelFrame, display: true)
            hostingView.setFrameSize(NSSize(width: panelWidth, height: panelHeight))
        }
    }
}
