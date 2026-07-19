//
//  WelcomeWindowController.swift
//  Superclip
//

import AppKit
import SwiftUI

final class WelcomeWindowController: NSWindowController, NSWindowDelegate {
    static let hasSeenWelcomeKey = "Superclip.hasSeenWelcome"

    private var onComplete: (() -> Void)?

    override init(window: NSWindow?) {
        let win = window ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 740),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.backgroundColor = .windowBackgroundColor
        super.init(window: win)
        win.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        let view = OnboardingView(onComplete: { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.hasSeenWelcomeKey)
            self?.window?.close()
        })
        let hostingController = NSHostingController(rootView: view)
        window?.contentViewController = hostingController
        let fittingSize = hostingController.view.fittingSize
        window?.setContentSize(fittingSize)
    }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: Self.hasSeenWelcomeKey)
        onComplete?()
        onComplete = nil
    }
}
