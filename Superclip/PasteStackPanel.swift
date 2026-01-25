//
//  PasteStackPanel.swift
//  Superclip
//

import AppKit
import SwiftUI
import Combine

class PasteStackPanel: NSPanel {
    weak var appDelegate: AppDelegate?
    let pasteStackManager: PasteStackManager
    let navigationState = NavigationState()
    private var cancellable: AnyCancellable?
    
    // Layout constants
    private let panelWidth: CGFloat = 320
    private let headerHeight: CGFloat = 44
    private let emptyStateHeight: CGFloat = 150
    private let itemRowHeight: CGFloat = 58
    private let verticalPadding: CGFloat = 16
    private let minHeight: CGFloat = 150
    private let maxHeight: CGFloat = 600
    private let screenPadding: CGFloat = 16
    
    init(pasteStackManager: PasteStackManager) {
        self.pasteStackManager = pasteStackManager
        
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .titled],
            backing: .buffered,
            defer: true
        )
        
        setupWindow()
        setupContentView()
        observeStackChanges()
    }
    
    override var canBecomeKey: Bool { true }
    
    private func setupWindow() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true // Allow dragging the panel
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // Keep panel on top and visible across all spaces
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary
        ]
        
        // Make it a floating panel that stays on top
        hidesOnDeactivate = false
    }
    
    private func setupContentView() {
        let contentView = PasteStackView(
            pasteStackManager: pasteStackManager,
            navigationState: navigationState,
            onClose: {
                self.appDelegate?.closePasteStackWindow(andPaste: false)
            }
        ) { shouldPaste in
            self.appDelegate?.handlePasteStackPaste(shouldPaste: shouldPaste)
        }
        
        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
        
        let panelHeight = calculateHeight(for: pasteStackManager.stackItems.count)
        positionWindow(withHeight: panelHeight, animated: false)
    }
    
    private func observeStackChanges() {
        cancellable = pasteStackManager.$stackItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.updateWindowHeight(for: items.count)
            }
    }
    
    private func calculateHeight(for itemCount: Int) -> CGFloat {
        if itemCount == 0 {
            return headerHeight + emptyStateHeight
        }
        
        let contentHeight = headerHeight + (CGFloat(itemCount) * itemRowHeight) + verticalPadding
        return min(max(contentHeight, minHeight), maxHeight)
    }
    
    private func updateWindowHeight(for itemCount: Int) {
        let newHeight = calculateHeight(for: itemCount)
        positionWindow(withHeight: newHeight, animated: true)
    }
    
    private func positionWindow(withHeight panelHeight: CGFloat, animated: Bool) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // Keep x position, adjust y to keep window vertically centered
        let xPosition = frame.origin.x != 0 ? frame.origin.x : screenFrame.maxX - panelWidth - screenPadding
        let yPosition = screenFrame.minY + (screenFrame.height - panelHeight) / 2
        
        let newFrame = NSRect(
            x: xPosition,
            y: yPosition,
            width: panelWidth,
            height: panelHeight
        )
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true)
        }
        
        contentView?.setFrameSize(NSSize(width: panelWidth, height: panelHeight))
    }
}
