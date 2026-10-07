//
//  ScreenCaptureManager.swift
//  Superclip
//

import AppKit
import ScreenCaptureKit

/// The display a capture is for, fixed at the moment the capture overlay opens.
///
/// Captures used to ask `NSScreen.main` which display to read *at capture
/// time*. While the overlay is up that is not the display the overlay is on:
/// the overlay panel can be key but never main, so with the overlay on a
/// second display AppKit still reported the primary one. The rectangle
/// selected on display 2 was then read from display 1.
struct CaptureTarget {
  let displayID: CGDirectDisplayID
  /// The display's frame in AppKit's global coordinates (origin bottom-left).
  let frame: NSRect
  let scale: CGFloat

  init(screen: NSScreen) {
    let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    displayID = number.map { CGDirectDisplayID($0.uint32Value) } ?? CGMainDisplayID()
    frame = screen.frame
    scale = screen.backingScaleFactor
  }

  /// The screen the pointer is on: where the user is about to select.
  static func screenUnderPointer() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
  }

  /// This display's top-left corner in Core Graphics global coordinates
  /// (origin at the top-left of the primary display, y growing downward).
  /// ScreenCaptureKit reports window frames in this space.
  var cgOrigin: CGPoint {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.height
    return CGPoint(x: frame.minX, y: primaryHeight - frame.maxY)
  }
}

/// Shared capture engine for area, fullscreen, and window screenshot capture.
/// Used by both the OCR flow and the screenshot capture flow.
class ScreenCaptureManager {

  private func display(for target: CaptureTarget, in content: SCShareableContent) throws -> SCDisplay {
    // No silent fallback to "the first display": capturing the wrong screen
    // is worse than reporting that the right one was not found.
    guard let display = content.displays.first(where: { $0.displayID == target.displayID }) else {
      throw ScreenCaptureError.noDisplay
    }
    return display
  }

  private func filter(for display: SCDisplay, in content: SCShareableContent) -> SCContentFilter {
    let ourBundleID = Bundle.main.bundleIdentifier ?? ""
    let windowsToExclude = content.windows.filter {
      $0.owningApplication?.bundleIdentifier == ourBundleID
    }
    return SCContentFilter(display: display, excludingWindows: windowsToExclude)
  }

  /// Capture a rectangular region of the target display. `rect` is in the
  /// display's own points, origin top-left.
  func captureArea(rect: NSRect, on target: CaptureTarget) async throws -> NSImage {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    let display = try display(for: target, in: content)

    let config = SCStreamConfiguration()
    config.sourceRect = rect
    config.width = Int(rect.width * target.scale)
    config.height = Int(rect.height * target.scale)
    config.scalesToFit = true
    config.showsCursor = false
    config.pixelFormat = kCVPixelFormatType_32BGRA

    let cgImage = try await SCScreenshotManager.captureImage(
      contentFilter: filter(for: display, in: content),
      configuration: config
    )

    return NSImage(cgImage: cgImage, size: NSSize(width: rect.width, height: rect.height))
  }

  /// Capture the whole target display.
  func captureFullscreen(on target: CaptureTarget) async throws -> NSImage {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    let display = try display(for: target, in: content)

    let config = SCStreamConfiguration()
    config.width = Int(target.frame.width * target.scale)
    config.height = Int(target.frame.height * target.scale)
    config.scalesToFit = true
    config.showsCursor = false
    config.pixelFormat = kCVPixelFormatType_32BGRA

    let cgImage = try await SCScreenshotManager.captureImage(
      contentFilter: filter(for: display, in: content),
      configuration: config
    )

    return NSImage(cgImage: cgImage, size: target.frame.size)
  }

  /// Capture a specific window at the given display scale.
  func captureWindow(_ window: SCWindow, scale: CGFloat) async throws -> NSImage {
    let filter = SCContentFilter(desktopIndependentWindow: window)

    let config = SCStreamConfiguration()
    config.width = Int(CGFloat(window.frame.width) * scale)
    config.height = Int(CGFloat(window.frame.height) * scale)
    config.scalesToFit = true
    config.showsCursor = false
    config.pixelFormat = kCVPixelFormatType_32BGRA

    let cgImage = try await SCScreenshotManager.captureImage(
      contentFilter: filter,
      configuration: config
    )

    return NSImage(
      cgImage: cgImage,
      size: NSSize(width: window.frame.width, height: window.frame.height)
    )
  }

  /// List on-screen windows, excluding our own app's windows.
  func availableWindows() async throws -> [SCWindow] {
    let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
    let ourBundleID = Bundle.main.bundleIdentifier ?? ""

    return content.windows.filter { window in
      window.owningApplication?.bundleIdentifier != ourBundleID
        && window.frame.width > 0
        && window.frame.height > 0
        && window.isOnScreen
    }
  }
}

enum ScreenCaptureError: LocalizedError {
  case noDisplay
  case captureFailed(Error)

  var errorDescription: String? {
    switch self {
    case .noDisplay:
      return "Could not find a display to capture."
    case .captureFailed(let error):
      return "Screen capture failed: \(error.localizedDescription)"
    }
  }
}
