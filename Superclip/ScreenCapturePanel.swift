//
//  ScreenCapturePanel.swift
//  Superclip
//

import AppKit
import SwiftUI

class ScreenCapturePanel: NSPanel {
    var onCapture: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?
    private var localKeyMonitor: Any?
    private let screenFrame: NSRect

    init(screenFrame: NSRect) {
        self.screenFrame = screenFrame

        super.init(
            contentRect: screenFrame,
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
        hasShadow = false
        level = .screenSaver  // Highest level to cover everything
        ignoresMouseEvents = false
        isMovable = false
        isMovableByWindowBackground = false

        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        // Hide cursor and use crosshair
        NSCursor.crosshair.set()
    }

    private func setupContentView() {
        let captureView = ScreenCaptureView(
            screenFrame: screenFrame,
            onCapture: { [weak self] rect in
                self?.handleCapture(rect)
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            }
        )

        let hostingView = NSHostingView(rootView: captureView)
        self.contentView = hostingView
    }

    private func setupKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isKeyWindow else { return event }

            // Escape key - cancel
            if event.keyCode == 53 {
                self.handleCancel()
                return nil
            }

            return event
        }
    }

    private func handleCapture(_ rect: NSRect) {
        // Restore cursor
        NSCursor.arrow.set()

        // Store callback before closing
        let captureCallback = onCapture

        // Hide window immediately (orderOut is faster than close for visual hiding)
        orderOut(nil)

        // Close the panel
        closePanel()

        // Longer delay to ensure window is fully gone from screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            captureCallback?(rect)
        }
    }

    private func handleCancel() {
        // Restore cursor
        NSCursor.arrow.set()

        closePanel()
        onCancel?()
    }

    private func closePanel() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        close()
    }
}
