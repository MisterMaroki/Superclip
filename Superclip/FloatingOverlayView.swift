//
//  FloatingOverlayView.swift
//  Superclip
//

import AppKit
import SwiftUI

struct FloatingOverlayView: View {
  let image: NSImage
  let onCopy: () -> Void
  let onSave: () -> Void
  let onAnnotate: () -> Void
  let onClose: () -> Void

  @State private var isHovered: Bool

  /// - Parameter showsActions: start with the buttons visible (used when
  ///   rendering the overlay for review; in the app they appear on hover).
  init(
    image: NSImage, showsActions: Bool = false, onCopy: @escaping () -> Void,
    onSave: @escaping () -> Void, onAnnotate: @escaping () -> Void, onClose: @escaping () -> Void
  ) {
    self.image = image
    self.onCopy = onCopy
    self.onSave = onSave
    self.onAnnotate = onAnnotate
    self.onClose = onClose
    _isHovered = State(initialValue: showsActions)
  }

  private let contentWidth: CGFloat = FloatingOverlayPanel.toastWidth

  /// Fixed 16:10 landscape ratio (matches macOS screen proportions)
  private var imageHeight: CGFloat {
    contentWidth * 10 / 16
  }

  var body: some View {
    ZStack {
      // Screenshot thumbnail
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: contentWidth, height: imageHeight)
        .clipShape(Rectangle())

      // Hover overlay
      if isHovered {
        // Dark enough that the buttons read the same over a white page or a
        // dark one; the capture stays recognisable underneath
        Color.black.opacity(0.62)
          .clipShape(Rectangle())
          .transition(.opacity)

        // Corner icons: Edit (top-left), Close (top-right)
        VStack {
          HStack {
            OverlayCornerButton(icon: "xmark", label: "Dismiss", action: onClose)
            Spacer()
            OverlayCornerButton(icon: "pencil", label: "Annotate", action: onAnnotate)
          }
          .padding(8)
          Spacer()
        }
        .transition(.opacity)

        // Center actions: Copy & Save stacked
        VStack(spacing: 8) {
          OverlayTextButton(label: "Copy", isPrimary: true, action: onCopy)
          OverlayTextButton(label: "Save", isPrimary: false, action: onSave)
        }
        .transition(.opacity)
      }
    }
    .frame(width: contentWidth, height: imageHeight)
    .clipShape(Rectangle())
    .overlay(
      Rectangle()
        .stroke(Brand.gray200, lineWidth: 1)
    )
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
      }
    }
  }
}

// MARK: - Corner icon button (Edit / Close)

/// White square, black glyph: reads at a glance on the dark scrim. (Dark grey
/// buttons on a dark scrim were close to invisible.)
private struct OverlayCornerButton: View {
  let icon: String
  let label: String
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Color.black)
        .frame(width: 24, height: 24)
        .background(Color.white.opacity(isHovered ? 1 : 0.88))
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel(label)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.1)) {
        isHovered = hovering
      }
    }
  }
}

// MARK: - Center text button (Copy / Save)

/// Copy is the main action: solid white with black text. Save is secondary:
/// a white outline that fills on hover. Fixed black and white on purpose,
/// since they sit on a scrim over the capture, not on app chrome.
private struct OverlayTextButton: View {
  let label: String
  let isPrimary: Bool
  let action: () -> Void

  @State private var isHovered = false

  private var fill: Color {
    if isPrimary { return Color.white.opacity(isHovered ? 1 : 0.94) }
    return isHovered ? Color.white : Color.black.opacity(0.35)
  }

  private var text: Color {
    isPrimary || isHovered ? .black : .white
  }

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(text)
        .frame(width: 120, height: 32)
        .background(Rectangle().fill(fill))
        .overlay(
          Rectangle()
            .strokeBorder(Color.white, lineWidth: isPrimary ? 0 : 1.5)
        )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.1)) {
        isHovered = hovering
      }
    }
  }
}
