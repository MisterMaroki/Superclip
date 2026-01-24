//
//  WelcomeView.swift
//  Superclip
//

import AppKit
import SwiftUI

class ContentPanel: NSPanel {
    weak var appDelegate: AppDelegate?
    
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .titled],
            backing: .buffered,
            defer: true
        )
        
        setupWindow()
        setupContentView()
    }
    
    private func setupWindow() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .floating
        isMovableByWindowBackground = true
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
        let contentView = ContentView() {
            self.close()
        }
        
        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
        
        hostingView.setFrameSize(hostingView.fittingSize)
        
        if let screen = NSScreen.main {
            let padding: CGFloat = 20
            
            let screenFrame = screen.visibleFrame
            let xPosition = screenFrame.maxX - hostingView.frame.width - padding
            let yPosition = screenFrame.minY + padding
            
            setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
            setContentSize(hostingView.frame.size)
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
