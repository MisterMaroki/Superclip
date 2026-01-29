//
//  WelcomeWindowController.swift
//  Superclip
//

import AppKit
import ApplicationServices
import SwiftUI

final class WelcomeWindowController: NSWindowController, NSWindowDelegate {
    static let hasSeenOnboardingKey = "Superclip.hasSeenOnboarding"

    private var onComplete: (() -> Void)?

    convenience init(onComplete: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        self.onComplete = onComplete

        window.title = "Welcome to Superclip"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.delegate = self

        let onboardingView = OnboardingView {
            self.finishOnboarding()
        }
        window.contentViewController = NSHostingController(rootView: onboardingView)
    }

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static var needsOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: hasSeenOnboardingKey)
    }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finishOnboarding() {
        // close() triggers windowWillClose which handles the rest
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let callback = onComplete else { return }
        onComplete = nil  // Prevent double-call if close is triggered multiple ways
        UserDefaults.standard.set(true, forKey: Self.hasSeenOnboardingKey)
        callback()
    }
}
