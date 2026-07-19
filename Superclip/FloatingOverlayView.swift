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

  @State private var isHovered = false

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
        Color.black.opacity(0.5)
          .clipShape(Rectangle())
          .transition(.opacity)

        // Corner icons: Edit (top-left), Close (top-right)
        VStack {
          HStack {
            OverlayCornerButton(icon: "xmark", action: onClose)
            Spacer()
            OverlayCornerButton(icon: "pencil", action: onAnnotate)
          }
          .padding(8)
          Spacer()
        }
        .transition(.opacity)

        // Center actions: Copy & Save stacked
        VStack(spacing: 8) {
          OverlayTextButton(label: "Copy", action: onCopy)
          OverlayTextButton(label: "Save", action: onSave)
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

private struct OverlayCornerButton: View {
  let icon: String
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Brand.white)
        .frame(width: 24, height: 24)
        .background(
          Rectangle()
            .fill(Color(white: isHovered ? 0.35 : 0.2))
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

// MARK: - Center text button (Copy / Save)

private struct OverlayTextButton: View {
  let label: String
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Brand.white)
        .frame(width: 120, height: 32)
        .background(
          Rectangle()
            .fill(Color(white: isHovered ? 0.35 : 0.2))
        )
        .overlay(
          Rectangle()
            .stroke(Color.white.opacity(isHovered ? 0.4 : 0.2), lineWidth: 0.5)
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
