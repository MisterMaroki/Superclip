//
//  PreviewPanel.swift
//  Superclip
//

import AppKit
import SwiftUI
import Combine

class PreviewEditingState: ObservableObject {
    @Published var isEditing: Bool = false
    @Published var shouldCancelEditing: Bool = false
    
    func cancelEditing() {
        shouldCancelEditing = true
    }
}

class PreviewPanel: NSPanel {
    weak var appDelegate: AppDelegate?
    let item: ClipboardItem
    let clipboardManager: ClipboardManager
    var onDismiss: (() -> Void)?
    let editingState = PreviewEditingState()
    
    init(item: ClipboardItem, clipboardManager: ClipboardManager) {
        self.item = item
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
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary
        ]
        
        delegate = self
    }
    
    private func setupContentView() {
        let previewView = PreviewView(
            item: item,
            clipboardManager: clipboardManager,
            editingState: editingState,
            onDismiss: { [weak self] in
                self?.onDismiss?()
            },
            onPaste: { [weak self] updatedContent in
                self?.handlePaste(updatedContent: updatedContent)
            },
            onOpenEditor: { [weak self] item, frame in
                self?.appDelegate?.showRichTextEditorWindow(for: item, fromPreviewFrame: frame)
            }
        )

        let hostingView = NSHostingView(rootView: previewView)
        self.contentView = hostingView

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth: CGFloat = 500
            let panelHeight: CGFloat = 400

            // Center the panel on screen, slightly above center
            let xPosition = screenFrame.midX - (panelWidth / 2)
            let yPosition = screenFrame.midY - (panelHeight / 2) + 50

            hostingView.setFrameSize(NSSize(width: panelWidth, height: panelHeight))

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
    
    private func handlePaste(updatedContent: String) {
        // Update clipboard with edited content
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(updatedContent, forType: .string)
        
        onDismiss?()
        
        // Trigger paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.appDelegate?.simulatePastePublic()
        }
    }
}

extension PreviewPanel: NSWindowDelegate {
    // Preview panel stays open until explicitly closed
    // No auto-close on losing focus
}
