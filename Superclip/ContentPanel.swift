//
//  WelcomeView.swift
//  Superclip
//

import AppKit
import SwiftUI

class ContentPanel: NSPanel {
  weak var appDelegate: AppDelegate?
  let clipboardManager: ClipboardManager
  let pinboardManager: PinboardManager
  let settings: SettingsManager
  let navigationState = NavigationState()
  var isEditingPinboard: Bool = false
  var isSearching: Bool = false
  var isSearchFieldFocused: Bool = false

  init(clipboardManager: ClipboardManager, pinboardManager: PinboardManager, settings: SettingsManager) {
    self.clipboardManager = clipboardManager
    self.pinboardManager = pinboardManager
    self.settings = settings

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
    isMovableByWindowBackground = false  // Don't allow moving the bottom bar
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    animationBehavior = .none  // Disable default macOS window animations

    collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
    ]

    // Set delegate to handle window events
    delegate = self
  }

  private func setupContentView() {
    let contentView = ContentView(
      clipboardManager: clipboardManager,
      navigationState: navigationState,
      pinboardManager: pinboardManager,
      settings: settings,
      dismiss: { shouldPaste in
        self.appDelegate?.closeReviewWindow(andPaste: shouldPaste)
      },
      onPreview: { [weak self] item, index, cardCenterX in
        self?.appDelegate?.showPreviewWindow(for: item, atIndex: index, cardCenterX: cardCenterX)
      },
      onEditingPinboardChanged: { [weak self] isEditing in
        self?.isEditingPinboard = isEditing
      },
      onTextSnipe: { [weak self] in
        self?.appDelegate?.startScreenCapture()
      },
      onSearchingChanged: { [weak self] isSearching in
        self?.isSearching = isSearching
      },
      onSearchFocusChanged: { [weak self] isFocused in
        self?.isSearchFieldFocused = isFocused
      },
    
      onEditItem: { [weak self] item in
        guard let self = self, let appDelegate = self.appDelegate else { return }
        let drawerFrame = self.frame
        let panelWidth: CGFloat = 500
        let panelHeight: CGFloat = 400
        let idx = self.navigationState.selectedIndex
        let cardWidth: CGFloat = 220
        let cardSpacing: CGFloat = 14
        let horizontalPadding: CGFloat = 20
        let cardStartX = drawerFrame.minX + horizontalPadding
        let cardCenterX = cardStartX + (CGFloat(idx) * (cardWidth + cardSpacing)) + (cardWidth / 2)
        var editorX = cardCenterX - (panelWidth / 2)
        if let screen = NSScreen.main {
          let screenFrame = screen.visibleFrame
          editorX = max(screenFrame.minX + 16, min(editorX, screenFrame.maxX - panelWidth - 16))
        }
        let editorY = drawerFrame.maxY + 12
        let editorFrame = NSRect(x: editorX, y: editorY, width: panelWidth, height: panelHeight)
        appDelegate.showRichTextEditorWindow(for: item, fromPreviewFrame: editorFrame)
      },  onOpenSettings: { [weak self] in
          self?.appDelegate?.openSettingsWindow()
        },
    )

    let hostingView = NSHostingView(rootView: contentView)
    self.contentView = hostingView

    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame
      let padding: CGFloat = 16
      let bottomPadding: CGFloat = 16
      let panelHeight: CGFloat = 280  // Height for Paste-style horizontal cards

      // Set panel to span across the bottom of the screen
      let panelWidth = screenFrame.width - (padding * 2)
      let xPosition = screenFrame.minX + padding
      let yPosition = screenFrame.minY + bottomPadding

      // Set the hosting view size first
      hostingView.setFrameSize(NSSize(width: panelWidth, height: panelHeight))

      let finalFrame = NSRect(x: xPosition, y: yPosition, width: panelWidth, height: panelHeight)
      let offscreenY = screenFrame.minY - panelHeight
      let offscreenFrame = NSRect(x: xPosition, y: offscreenY, width: panelWidth, height: panelHeight)

      // Show window at final position first to ensure it's rendered
      setFrame(finalFrame, display: true)
      alphaValue = 1.0
      orderFront(nil)
      makeKey()

      // Instantly move to offscreen position (no animation)
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      setFrame(offscreenFrame, display: true)
      CATransaction.commit()

      // Animate up to final position
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.1
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        self.animator().setFrame(finalFrame, display: true)
      }
    }
  }

  func animateClose(completion: @escaping () -> Void) {
    guard let screen = NSScreen.main else {
      completion()
      return
    }

    let offscreenY = screen.visibleFrame.minY - frame.height
    let offscreenFrame = NSRect(x: frame.origin.x, y: offscreenY, width: frame.width, height: frame.height)

    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.1
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      self.animator().setFrame(offscreenFrame, display: true)
    }, completionHandler: completion)
  }
}

extension ContentPanel: NSWindowDelegate {
  func windowDidResignKey(_ notification: Notification) {
    // Use a small delay to check which window becomes key (handles timing issues)
    DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
      guard let self = self else { return }

      // Don't close if a drag is in progress
      if DragState.shared.draggedItemId != nil {
        return
      }

      // Check which window is now key
      let keyWindow = NSApplication.shared.keyWindow

      // If paste stack is becoming key, don't close
      if let pasteStackWindow = self.appDelegate?.pasteStackWindow,
        pasteStackWindow.isVisible && keyWindow === pasteStackWindow
      {
        return
      }
      // If preview is becoming key, don't close (user clicked on preview)
      if let previewWindow = self.appDelegate?.previewWindow,
        previewWindow.isVisible && keyWindow === previewWindow
      {
        return
      }
      // If settings window is becoming key, don't close
      if let settingsWindow = self.appDelegate?.settingsWindow,
        settingsWindow.isVisible && keyWindow === settingsWindow
      {
        return
      }
      // Otherwise, close both preview and drawer (clicked outside the app)
      self.appDelegate?.closeReviewWindow(andPaste: false)
    }
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
