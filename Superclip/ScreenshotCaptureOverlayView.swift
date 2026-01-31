//
//  ScreenshotCaptureOverlayView.swift
//  Superclip
//

import SwiftUI
import AppKit
import ScreenCaptureKit

enum ScreenshotCaptureMode: String, CaseIterable {
  case area = "Area"
  case window = "Window"
  case fullscreen = "Fullscreen"

  var icon: String {
    switch self {
    case .area: return "rectangle.dashed"
    case .window: return "macwindow"
    case .fullscreen: return "rectangle.inset.filled"
    }
  }
}

struct ScreenshotCaptureOverlayView: View {
  let screenFrame: NSRect
  let captureManager: ScreenCaptureManager
  let onCapture: (NSImage) -> Void
  let onCancel: () -> Void

  @State private var mode: ScreenshotCaptureMode = .area
  @State private var dragStart: CGPoint?
  @State private var dragCurrent: CGPoint?
  @State private var mousePosition: CGPoint? = nil

  // Window mode state
  @State private var availableWindows: [SCWindow] = []
  @State private var hoveredWindowFrame: CGRect?
  @State private var isLoadingWindows = false

  var selectionRect: NSRect? {
    guard let start = dragStart, let current = dragCurrent else { return nil }
    let minX = min(start.x, current.x)
    let minY = min(start.y, current.y)
    let maxX = max(start.x, current.x)
    let maxY = max(start.y, current.y)
    return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Semi-transparent overlay
        Color.black.opacity(0.1)
          .ignoresSafeArea()

        // Mode-specific content
        switch mode {
        case .area:
          areaOverlay(geometry: geometry)
        case .window:
          windowOverlay(geometry: geometry)
        case .fullscreen:
          fullscreenOverlay()
        }

        // Mode toolbar at top
        VStack {
          modeToolbar
            .padding(.top, 60)
          Spacer()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onAppear {
      // Initialize mouse position
      let mouseLocation = NSEvent.mouseLocation
      let viewX = mouseLocation.x - screenFrame.minX
      let viewY = screenFrame.height - (mouseLocation.y - screenFrame.minY)
      mousePosition = CGPoint(x: viewX, y: viewY)

      // Only load windows if starting in window mode
      if mode == .window {
        loadWindows()
      }
    }
    .onDisappear {
      // Release SCWindow references to free ScreenCaptureKit resources
      availableWindows.removeAll()
    }
    .onChange(of: mode) { _, newMode in
      if newMode == .window {
        loadWindows()
      } else {
        // Release SCWindow references when leaving window mode
        availableWindows.removeAll()
        hoveredWindowFrame = nil
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .screenshotCaptureCycleMode)) { _ in
      let allModes = ScreenshotCaptureMode.allCases
      if let currentIndex = allModes.firstIndex(of: mode) {
        let nextIndex = (currentIndex + 1) % allModes.count
        withAnimation(.easeInOut(duration: 0.15)) {
          mode = allModes[nextIndex]
        }
        dragStart = nil
        dragCurrent = nil
        hoveredWindowFrame = nil
      }
    }
  }

  // MARK: - Mode Toolbar

  var modeToolbar: some View {
    HStack(spacing: 4) {
      ForEach(ScreenshotCaptureMode.allCases, id: \.self) { captureMode in
        Button {
          withAnimation(.easeInOut(duration: 0.15)) {
            mode = captureMode
          }
          // Reset area selection when switching modes
          dragStart = nil
          dragCurrent = nil
          hoveredWindowFrame = nil
        } label: {
          HStack(spacing: 6) {
            Image(systemName: captureMode.icon)
              .font(.system(size: 12, weight: .medium))
            Text(captureMode.rawValue)
              .font(.system(size: 13, weight: .medium))
          }
          .foregroundStyle(mode == captureMode ? .white : .primary)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(mode == captureMode ? Color.accentColor : Color.clear)
          )
        }
        .buttonStyle(.plain)
      }

      Rectangle()
        .fill(Color.primary.opacity(0.2))
        .frame(width: 1, height: 20)
        .padding(.horizontal, 8)

      HStack(spacing: 6) {
        Text("ESC")
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.primary.opacity(0.2))
          .cornerRadius(4)
        Text("Cancel")
          .font(.system(size: 13))
      }
      .foregroundStyle(.primary.opacity(0.7))

      Rectangle()
        .fill(Color.primary.opacity(0.2))
        .frame(width: 1, height: 20)
        .padding(.horizontal, 8)

      HStack(spacing: 6) {
        Text("TAB")
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.primary.opacity(0.2))
          .cornerRadius(4)
        Text("Switch mode")
          .font(.system(size: 13))
      }
      .foregroundStyle(.primary.opacity(0.7))
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(Color.black.opacity(0.6))
    .cornerRadius(10)
  }

  // MARK: - Area Mode

  @ViewBuilder
  func areaOverlay(geometry: GeometryProxy) -> some View {
    ZStack {
      // Selection rectangle cutout
      if let rect = selectionRect, rect.width > 10 && rect.height > 10 {
        SelectionOverlay(selectionRect: rect, screenSize: geometry.size)
      }

      // Crosshair cursor
      if let position = mousePosition, dragStart == nil {
        CrosshairView(position: position, screenSize: geometry.size)
      }

      // Dimension label
      if let rect = selectionRect, rect.width > 10 && rect.height > 10 {
        screenshotDimensionLabel(for: rect)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          if dragStart == nil {
            dragStart = value.startLocation
          }
          dragCurrent = value.location
          mousePosition = value.location
        }
        .onEnded { _ in
          if let rect = selectionRect, rect.width >= 10 && rect.height >= 10 {
            captureAreaRegion(rect)
          }
          dragStart = nil
          dragCurrent = nil
        }
    )
    .onContinuousHover { phase in
      switch phase {
      case .active(let location):
        if dragStart == nil {
          mousePosition = location
        }
      case .ended:
        break
      }
    }
  }

  @ViewBuilder
  func screenshotDimensionLabel(for rect: NSRect) -> some View {
    let text = "\(Int(rect.width)) x \(Int(rect.height))"
    Text(text)
      .font(.system(size: 11, weight: .medium, design: .monospaced))
      .foregroundStyle(.primary)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.black.opacity(0.7))
      .cornerRadius(4)
      .position(
        x: rect.midX,
        y: rect.maxY + 20
      )
  }

  // MARK: - Window Mode

  @ViewBuilder
  func windowOverlay(geometry: GeometryProxy) -> some View {
    ZStack {
      // Highlight hovered window
      if let windowFrame = hoveredWindowFrame {
        // Convert from screen coordinates to view coordinates
        let viewRect = screenToView(windowFrame, screenFrame: screenFrame)
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.accentColor.opacity(0.15))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.accentColor, lineWidth: 3)
          )
          .frame(width: viewRect.width, height: viewRect.height)
          .position(x: viewRect.midX, y: viewRect.midY)
      }

      // Instructions if no window is hovered
      if hoveredWindowFrame == nil && !isLoadingWindows {
        VStack(spacing: 8) {
          Image(systemName: "cursorarrow.click.2")
            .font(.system(size: 28))
            .foregroundStyle(.primary.opacity(0.5))
          Text("Hover over a window and click to capture")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary.opacity(0.6))
        }
        .padding(20)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())
    .onContinuousHover { phase in
      switch phase {
      case .active(let location):
        mousePosition = location
        updateHoveredWindow(at: location)
      case .ended:
        hoveredWindowFrame = nil
      }
    }
    .onTapGesture {
      captureHoveredWindow()
    }
  }

  // MARK: - Fullscreen Mode

  @ViewBuilder
  func fullscreenOverlay() -> some View {
    VStack(spacing: 16) {
      Image(systemName: "rectangle.inset.filled")
        .font(.system(size: 36))
        .foregroundStyle(.primary.opacity(0.6))

      Text("Click anywhere to capture the full screen")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.primary.opacity(0.7))
    }
    .padding(24)
    .background(Color.black.opacity(0.5))
    .cornerRadius(12)
    .contentShape(Rectangle())
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.clear)
    .contentShape(Rectangle())
    .onTapGesture {
      captureFullscreenImage()
    }
  }

  // MARK: - Capture Actions

  private func captureAreaRegion(_ rect: NSRect) {
    let captureRect = NSRect(
      x: rect.minX,
      y: rect.minY,
      width: rect.width,
      height: rect.height
    )

    Task {
      do {
        let image = try await captureManager.captureArea(rect: captureRect)
        await MainActor.run {
          onCapture(image)
        }
      } catch {
        await MainActor.run {
          onCancel()
        }
      }
    }
  }

  private func captureHoveredWindow() {
    guard let mousePos = mousePosition else { return }

    // Find the window under the cursor
    let screenPoint = viewToScreen(mousePos, screenFrame: screenFrame)
    guard let window = windowAt(screenPoint: screenPoint) else { return }

    Task {
      do {
        let image = try await captureManager.captureWindow(window)
        await MainActor.run {
          onCapture(image)
        }
      } catch {
        await MainActor.run {
          onCancel()
        }
      }
    }
  }

  private func captureFullscreenImage() {
    Task {
      do {
        let image = try await captureManager.captureFullscreen()
        await MainActor.run {
          onCapture(image)
        }
      } catch {
        await MainActor.run {
          onCancel()
        }
      }
    }
  }

  // MARK: - Window Helpers

  private func loadWindows() {
    isLoadingWindows = true
    Task {
      do {
        let windows = try await captureManager.availableWindows()
        await MainActor.run {
          availableWindows = windows
          isLoadingWindows = false
        }
      } catch {
        await MainActor.run {
          isLoadingWindows = false
        }
      }
    }
  }

  private func updateHoveredWindow(at viewPoint: CGPoint) {
    let screenPoint = viewToScreen(viewPoint, screenFrame: screenFrame)
    if let window = windowAt(screenPoint: screenPoint) {
      hoveredWindowFrame = window.frame
    } else {
      hoveredWindowFrame = nil
    }
  }

  private func windowAt(screenPoint: CGPoint) -> SCWindow? {
    // SCWindow frames use top-left origin (Core Graphics coordinates)
    // Find the topmost (smallest area first for best match) window containing the point
    for window in availableWindows {
      let frame = window.frame
      if frame.contains(screenPoint) {
        return window
      }
    }
    return nil
  }

  /// Convert view coordinates (SwiftUI, top-left origin) to screen coordinates (Core Graphics, top-left origin)
  private func viewToScreen(_ point: CGPoint, screenFrame: NSRect) -> CGPoint {
    CGPoint(
      x: screenFrame.minX + point.x,
      y: point.y  // Both SwiftUI and SCWindow use top-left origin
    )
  }

  /// Convert screen coordinates (Core Graphics, top-left origin) to view coordinates (SwiftUI)
  private func screenToView(_ rect: CGRect, screenFrame: NSRect) -> CGRect {
    CGRect(
      x: rect.minX - screenFrame.minX,
      y: rect.minY,  // Both use top-left origin in this context
      width: rect.width,
      height: rect.height
    )
  }
}
