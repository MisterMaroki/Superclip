//
//  FloatingOverlayView.swift
//  Superclip
//

import SwiftUI
import AppKit

struct FloatingOverlayView: View {
  let image: NSImage
  let onCopy: () -> Void
  let onSave: () -> Void
  let onAnnotate: () -> Void
  let onClose: () -> Void

  @State private var isHovered = false

  /// Fixed content width matching the panel's toast width minus padding.
  private let contentWidth: CGFloat = FloatingOverlayPanel.toastWidth - 24  // 12px padding each side

  private var thumbnailHeight: CGFloat {
    let imageSize = image.size
    guard imageSize.width > 0, imageSize.height > 0 else { return 120 }
    let aspect = imageSize.height / imageSize.width
    return min(max(contentWidth * aspect, 60), 160)
  }

  var body: some View {
    VStack(spacing: 0) {
      // Screenshot thumbnail
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: contentWidth, height: thumbnailHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(.top, 10)
        .padding(.horizontal, 12)

      // Action buttons
      actionButtons
        .padding(.top, 8)
        .padding(.bottom, 10)
        .padding(.horizontal, 10)
    }
    .frame(width: FloatingOverlayPanel.toastWidth)
    .background(
      VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  // MARK: - Action Buttons

  var actionButtons: some View {
    HStack(spacing: 6) {
      overlayActionButton(icon: "doc.on.doc", label: "Copy", action: onCopy)
      overlayActionButton(icon: "square.and.arrow.down", label: "Save", action: onSave)
      overlayActionButton(icon: "pencil.and.outline", label: "Edit", action: onAnnotate)

      Spacer()

      // Close button
      Button {
        onClose()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.5))
          .frame(width: 22, height: 22)
          .background(Color.primary.opacity(0.1))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .help("Dismiss")
    }
  }

  @ViewBuilder
  func overlayActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
    Button {
      action()
    } label: {
      HStack(spacing: 3) {
        Image(systemName: icon)
          .font(.system(size: 10, weight: .medium))
        Text(label)
          .font(.system(size: 10, weight: .medium))
      }
      .foregroundStyle(.primary.opacity(0.85))
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(Color.primary.opacity(0.1))
      .cornerRadius(5)
      .overlay(
        RoundedRectangle(cornerRadius: 5)
          .stroke(Color.primary.opacity(0.08), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}
