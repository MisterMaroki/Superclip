//
//  ScreenCaptureManager.swift
//  Superclip
//

import AppKit
import ScreenCaptureKit

/// Shared capture engine for area, fullscreen, and window screenshot capture.
/// Used by both the OCR flow and the screenshot capture flow.
class ScreenCaptureManager {

  /// Capture a rectangular region of the main display.
  func captureArea(rect: NSRect) async throws -> NSImage {
    let scaleFactor = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }

    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

    guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() })
      ?? content.displays.first
    else {
      throw ScreenCaptureError.noDisplay
    }

    let ourBundleID = Bundle.main.bundleIdentifier ?? ""
    let windowsToExclude = content.windows.filter {
      $0.owningApplication?.bundleIdentifier == ourBundleID
    }

    let filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)

    let config = SCStreamConfiguration()
    config.sourceRect = rect
    config.width = Int(rect.width * scaleFactor)
    config.height = Int(rect.height * scaleFactor)
    config.scalesToFit = true
    config.showsCursor = false
    config.pixelFormat = kCVPixelFormatType_32BGRA

    let cgImage = try await SCScreenshotManager.captureImage(
      contentFilter: filter,
      configuration: config
    )

    return NSImage(cgImage: cgImage, size: NSSize(width: rect.width, height: rect.height))
  }

  /// Capture the entire main display.
  func captureFullscreen() async throws -> NSImage {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

    guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() })
      ?? content.displays.first
    else {
      throw ScreenCaptureError.noDisplay
    }

    let ourBundleID = Bundle.main.bundleIdentifier ?? ""
    let windowsToExclude = content.windows.filter {
      $0.owningApplication?.bundleIdentifier == ourBundleID
    }

    let filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)

    let scaleFactor = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
    let screenFrame = await MainActor.run { NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080) }

    let config = SCStreamConfiguration()
    config.width = Int(screenFrame.width * scaleFactor)
    config.height = Int(screenFrame.height * scaleFactor)
    config.scalesToFit = true
    config.showsCursor = false
    config.pixelFormat = kCVPixelFormatType_32BGRA

    let cgImage = try await SCScreenshotManager.captureImage(
      contentFilter: filter,
      configuration: config
    )

    return NSImage(cgImage: cgImage, size: screenFrame.size)
  }

  /// Capture a specific window.
  func captureWindow(_ window: SCWindow) async throws -> NSImage {
    let filter = SCContentFilter(desktopIndependentWindow: window)

    let scaleFactor = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }

    let config = SCStreamConfiguration()
    config.width = Int(CGFloat(window.frame.width) * scaleFactor)
    config.height = Int(CGFloat(window.frame.height) * scaleFactor)
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
