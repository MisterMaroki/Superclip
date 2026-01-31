//
//  FloatingOverlayPanel.swift
//  Superclip
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

class FloatingOverlayPanel: NSPanel {
  weak var appDelegate: AppDelegate?
  /// Small downscaled thumbnail for display only (~256px wide).
  private let thumbnailImage: NSImage
  /// Compressed PNG data for copy/save/annotate actions.
  private let pngData: Data

  /// Fixed width for all toast overlays so they stack uniformly.
  static let toastWidth: CGFloat = 280

  init(thumbnail: NSImage, pngData: Data) {
    self.thumbnailImage = thumbnail
    self.pngData = pngData

    super.init(
      contentRect: NSRect(x: 0, y: 0, width: Self.toastWidth, height: 200),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )

    setupWindow()
    setupContentView()
  }

  deinit {
    contentView = nil
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  private func setupWindow() {
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    level = .floating
    isMovableByWindowBackground = false
    isMovable = false

    collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
    ]

    // Start fully transparent for fade-in
    alphaValue = 0
  }

  private func setupContentView() {
    let overlayView = FloatingOverlayView(
      image: thumbnailImage,
      onCopy: { [weak self] in
        self?.copyImage()
      },
      onSave: { [weak self] in
        self?.saveImage()
      },
      onAnnotate: { [weak self] in
        self?.annotateImage()
      },
      onClose: { [weak self] in
        self?.dismissOverlay()
      }
    )

    let hostingView = NSHostingView(rootView: overlayView)
    hostingView.autoresizingMask = [.width, .height]
    self.contentView = hostingView

    // Size to fit content but enforce fixed width
    let fittingSize = hostingView.fittingSize
    let newFrame = NSRect(
      x: frame.origin.x,
      y: frame.origin.y,
      width: Self.toastWidth,
      height: max(fittingSize.height, 100)
    )
    setFrame(newFrame, display: true)
  }

  /// Animate the panel to a target frame with spring-like timing.
  func animateToFrame(_ targetFrame: NSRect, duration: TimeInterval = 0.35) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      context.allowsImplicitAnimation = true
      self.animator().setFrame(targetFrame, display: true)
      self.animator().alphaValue = 1
    }
  }

  /// Fade out and then call completion.
  func animateOut(completion: @escaping () -> Void) {
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.2
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      self.animator().alphaValue = 0
    }, completionHandler: completion)
  }

  // MARK: - Actions

  private func copyImage() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setData(pngData, forType: .png)
    dismissOverlay()
  }

  private func saveImage() {
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.png]
    savePanel.nameFieldStringValue = "Screenshot \(formattedTimestamp()).png"
    savePanel.canCreateDirectories = true
    savePanel.level = .floating

    // App must be active for the save panel to present
    NSApp.activate(ignoringOtherApps: true)

    let dataToSave = pngData
    savePanel.begin { response in
      guard response == .OK, let url = savePanel.url else { return }
      try? dataToSave.write(to: url)
    }
  }

  private func annotateImage() {
    guard let appDelegate = appDelegate else { return }

    let editorFrame: NSRect
    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame
      let panelWidth: CGFloat = 800
      let panelHeight: CGFloat = 600
      editorFrame = NSRect(
        x: screenFrame.midX - panelWidth / 2,
        y: screenFrame.midY - panelHeight / 2,
        width: panelWidth,
        height: panelHeight
      )
    } else {
      editorFrame = NSRect(x: 100, y: 100, width: 800, height: 600)
    }

    let item = ClipboardItem(
      content: "Screenshot",
      type: .image,
      imageData: pngData,
      sourceApp: SourceApp(
        bundleIdentifier: Bundle.main.bundleIdentifier,
        name: "Superclip Screenshot",
        icon: NSApp.applicationIconImage
      )
    )

    appDelegate.showRichTextEditorWindow(for: item, fromPreviewFrame: editorFrame)
    dismissOverlay()
  }

  private func dismissOverlay() {
    appDelegate?.removeFloatingOverlay(self)
  }

  private func formattedTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    return formatter.string(from: Date())
  }
}
