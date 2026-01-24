//
//  WelcomeView.swift
//  Superclip
//

import AppKit
import SwiftUI

class ContentPanel: NSPanel {
    weak var appDelegate: AppDelegate?
    let clipboardManager: ClipboardManager
    let navigationState = NavigationState()
    
    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
        
        super.init(
            contentRect: .zero,
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
        isMovableByWindowBackground = false // Don't allow moving the bottom bar
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary
        ]
        
        // Set delegate to handle window events
        delegate = self
    }
    
    private func setupContentView() {
        let contentView = ContentView(
            clipboardManager: clipboardManager,
            navigationState: navigationState
        ) { shouldPaste in
            self.appDelegate?.closeReviewWindow(andPaste: shouldPaste)
        }
        
        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let padding: CGFloat = 20
            let bottomPadding: CGFloat = 20
            let panelHeight: CGFloat = 320 // Height for horizontal clipboard cards
            
            // Set panel to span across the bottom of the screen
            let panelWidth = screenFrame.width - (padding * 2)
            let xPosition = screenFrame.minX + padding
            let yPosition = screenFrame.minY + bottomPadding
            
            // Set the hosting view size first
            hostingView.setFrameSize(NSSize(width: panelWidth, height: panelHeight))
            
            // Set the window frame
            setFrame(
                NSRect(
                    x: xPosition,
                    y: yPosition,
                    width: panelWidth,
                    height: panelHeight
                ),
                display: false
            )
        }
    }
}

extension ContentPanel: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        // Close when window loses key status (user clicked elsewhere)
        close()
    }
    
    override func mouseDown(with event: NSEvent) {
        // If click is outside content view, close the panel
        let clickPoint = event.locationInWindow
        let contentRect = contentView?.frame ?? .zero
        
        if !contentRect.contains(clickPoint) {
            close()
        } else {
            super.mouseDown(with: event)
        }
    }
}
