//
//  WelcomeWindowController.swift
//  Superclip
//

import AppKit
import ApplicationServices
import SwiftUI

final class WelcomeWindowController: NSWindowController, NSWindowDelegate {
    static let hasSeenWelcomeKey = "Superclip.hasSeenWelcome"

    override init(window: NSWindow?) {
        let win = window ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Superclip"
        win.isReleasedWhenClosed = false
        super.init(window: win)
        win.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: Self.hasSeenWelcomeKey)
    }

    func configure(dismiss: @escaping () -> Void, openAccessibility: @escaping () -> Void) {
        let view = WelcomeView(onDismiss: dismiss, onOpenAccessibility: openAccessibility)
        window?.contentViewController = NSHostingController(rootView: view)
    }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func openAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
