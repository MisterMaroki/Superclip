//
//  PreviewPanel.swift
//  Superclip
//

import AppKit
import Combine
import SwiftUI

class PreviewEditingState: ObservableObject {
  @Published var isEditing: Bool = false
  @Published var shouldCancelEditing: Bool = false

  func cancelEditing() {
    shouldCancelEditing = true
  }
}

class PreviewPanel: NSPanel {
  weak var appDelegate: AppDelegate?
  private(set) var item: ClipboardItem
  let clipboardManager: ClipboardManager
  let pinboardManager: PinboardManager
  var onDismiss: (() -> Void)?
  let editingState = PreviewEditingState()

  /// The X position where the arrow should point (relative to screen)
  var arrowTargetX: CGFloat = 0

  init(item: ClipboardItem, clipboardManager: ClipboardManager, pinboardManager: PinboardManager, arrowTargetX: CGFloat = 0) {
    self.item = item
    self.clipboardManager = clipboardManager
    self.pinboardManager = pinboardManager
    self.arrowTargetX = arrowTargetX

    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel, .titled],
      backing: .buffered,
      defer: true
    )

    setupWindow()
    // Content view is set up after frame is configured via finalizeSetup()
  }

  /// Call this after setting the frame to create the content view with correct arrow position
  func finalizeSetup() {
    updateContentView()
  }

  override var canBecomeKey: Bool { true }

  private func setupWindow() {
    backgroundColor = .clear
    isOpaque = false
    hasShadow = false  // Disable window shadow to avoid box around arrow; shadows applied in SwiftUI
    level = .floating
    isMovableByWindowBackground = false
    titlebarAppearsTransparent = true
    titleVisibility = .hidden

    collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
    ]

    delegate = self
  }

  private func setupContentView() {
    updateContentView()
  }

  private func updateContentView() {
    updateContentViewWithItem(item, targetFrame: nil)
  }

  /// Update the preview to show a different item at a new position
  func updatePreview(item: ClipboardItem, frame: NSRect, arrowTargetX: CGFloat) {
    self.arrowTargetX = arrowTargetX

    // Update frame with animation
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.15
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      self.animator().setFrame(frame, display: true)
    }

    // Recreate content view with new item using target frame for arrow calculation
    updateContentViewWithItem(item, targetFrame: frame)
  }

  private func updateContentViewWithItem(_ newItem: ClipboardItem, targetFrame: NSRect? = nil) {
    // Calculate arrow position relative to the panel
    let panelFrame = targetFrame ?? self.frame
    let arrowXInPanel = arrowTargetX - panelFrame.minX

    let previewView = PreviewView(
      item: newItem,
      clipboardManager: clipboardManager,
      pinboardManager: pinboardManager,
      editingState: editingState,
      arrowXPosition: arrowXInPanel,
      onDismiss: { [weak self] in
        self?.onDismiss?()
      },
      onPaste: { [weak self] updatedContent in
        self?.handlePaste(updatedContent: updatedContent)
      },
      onOpenEditor: { [weak self] item, frame in
        self?.appDelegate?.showRichTextEditorWindow(for: item, fromPreviewFrame: frame)
      },
      onCloseAll: { [weak self] in
        // Close both preview and drawer
        self?.appDelegate?.closeReviewWindow(andPaste: false)
      }
    )

    let hostingView = NSHostingView(rootView: previewView)
    hostingView.wantsLayer = true
    hostingView.layer?.backgroundColor = .clear
    self.contentView = hostingView
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
