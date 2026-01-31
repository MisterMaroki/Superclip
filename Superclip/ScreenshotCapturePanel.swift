//
//  ScreenshotCapturePanel.swift
//  Superclip
//

import AppKit
import SwiftUI

class ScreenshotCapturePanel: NSPanel {
  var onCapture: ((NSImage) -> Void)?
  var onCancel: (() -> Void)?
  private var localKeyMonitor: Any?
  private let screenFrame: NSRect
  private let captureManager = ScreenCaptureManager()

  init(screenFrame: NSRect) {
    self.screenFrame = screenFrame

    super.init(
      contentRect: screenFrame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )

    setupWindow()
    setupContentView()
    setupKeyMonitor()
  }

  deinit {
    if let monitor = localKeyMonitor {
      NSEvent.removeMonitor(monitor)
      localKeyMonitor = nil
    }
    contentView = nil
    onCapture = nil
    onCancel = nil
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  private func setupWindow() {
    backgroundColor = .clear
    isOpaque = false
    hasShadow = false
    level = .screenSaver
    ignoresMouseEvents = false
    isMovable = false
    isMovableByWindowBackground = false

    collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
    ]

    NSCursor.crosshair.set()
  }

  private func setupContentView() {
    let overlayView = ScreenshotCaptureOverlayView(
      screenFrame: screenFrame,
      captureManager: captureManager,
      onCapture: { [weak self] image in
        self?.handleCapture(image)
      },
      onCancel: { [weak self] in
        self?.handleCancel()
      }
    )

    let hostingView = NSHostingView(rootView: overlayView)
    self.contentView = hostingView
  }

  private func setupKeyMonitor() {
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self = self, self.isKeyWindow else { return event }

      // Escape key — cancel
      if event.keyCode == 53 {
        self.handleCancel()
        return nil
      }

      // Tab key — cycle through modes
      if event.keyCode == 48 {
        self.cycleCaptureMode()
        return nil
      }

      return event
    }
  }

  /// Post a notification so the SwiftUI view can cycle modes
  private func cycleCaptureMode() {
    NotificationCenter.default.post(name: .screenshotCaptureCycleMode, object: nil)
  }

  private func handleCapture(_ image: NSImage) {
    NSCursor.arrow.set()

    let captureCallback = onCapture
    onCapture = nil
    onCancel = nil

    // Flash the screen white then fade out
    showCaptureFlash {
      self.cleanupPanel()
      captureCallback?(image)
    }
  }

  private func showCaptureFlash(completion: @escaping () -> Void) {
    // Replace content with a white flash
    let flashView = NSView(frame: NSRect(origin: .zero, size: frame.size))
    flashView.wantsLayer = true
    flashView.layer?.backgroundColor = NSColor.black.cgColor
    contentView = flashView
    alphaValue = 1

    // Fade out the flash
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.25
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      self.animator().alphaValue = 0
    }, completionHandler: completion)
  }

  private func handleCancel() {
    NSCursor.arrow.set()

    let cancelCallback = onCancel
    onCapture = nil
    onCancel = nil

    cleanupPanel()
    cancelCallback?()
  }

  private func cleanupPanel() {
    if let monitor = localKeyMonitor {
      NSEvent.removeMonitor(monitor)
      localKeyMonitor = nil
    }
    contentView = nil
    close()
  }
}

extension Notification.Name {
  static let screenshotCaptureCycleMode = Notification.Name("screenshotCaptureCycleMode")
}
