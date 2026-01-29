//
//  SettingsPanel.swift
//  Superclip
//

import AppKit
import SwiftUI

class SettingsPanel: NSPanel {
    weak var appDelegate: AppDelegate?

    init() {
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
            }
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
