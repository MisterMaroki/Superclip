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
            contentRect: NSRect(origin: .zero, size: OnboardingLayout.windowSize),
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
        // The view is a fixed size; don't let the hosting controller re-derive
        // the window frame (it would add the hidden titlebar's height).
        hostingController.sizingOptions = []
        window?.contentViewController = hostingController
        window?.setContentSize(OnboardingLayout.windowSize)
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
