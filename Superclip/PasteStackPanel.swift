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
    private let itemRowHeight: CGFloat = 50
    private let gridRowHeight: CGFloat = 102  // 96pt tile + 6pt spacing, 3 per row
    private let gridColumns = 3
    private var isGrid = false
    private let verticalPadding: CGFloat = 16
    private let minHeight: CGFloat = 150
    private let maxHeight: CGFloat = 600
    private let screenPadding: CGFloat = 16
    
    init(pasteStackManager: PasteStackManager) {
        self.pasteStackManager = pasteStackManager
        
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
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
        // Never take keyboard focus for a click. The stack has no text fields,
        // and if it becomes key the app the user is pasting into stops being
        // the paste target: clicking a row pasted nowhere and later Cmd+V
        // presses went to Superclip instead of that app.
        becomesKeyOnlyIfNeeded = true
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
            onClose: { [weak self] in
                self?.appDelegate?.closePasteStackWindow(andPaste: false)
            },
            onViewModeChanged: { [weak self] mode in
                guard let self = self else { return }
                self.isGrid = mode == .grid
                self.updateWindowHeight(for: self.pasteStackManager.stackItems.count)
            }
        ) { [weak self] shouldPaste in
            self?.appDelegate?.handlePasteStackPaste(shouldPaste: shouldPaste)
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
        
        let rowsHeight: CGFloat
        if isGrid {
            let rows = (itemCount + gridColumns - 1) / gridColumns
            rowsHeight = CGFloat(rows) * gridRowHeight
        } else {
            rowsHeight = CGFloat(itemCount) * itemRowHeight
        }
        let contentHeight = headerHeight + rowsHeight + verticalPadding
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
