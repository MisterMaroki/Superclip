//
//  ScreenCaptureView.swift
//  Superclip
//

import SwiftUI
import AppKit

struct ScreenCaptureView: View {
    let screenFrame: NSRect
    let onCapture: (NSRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var mousePosition: CGPoint? = nil  // nil until first mouse event

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
                // Semi-transparent dark overlay
                Color.black.opacity(0.1)
                    .ignoresSafeArea()

                // Selection rectangle cutout
                if let rect = selectionRect, rect.width > 10 && rect.height > 10 {
                    SelectionOverlay(selectionRect: rect, screenSize: geometry.size)
                }

                // Crosshair cursor - only show when we have a valid position
                if let position = mousePosition {
                    CrosshairView(position: position, screenSize: geometry.size)
                }

                // Instructions overlay (top center)
                VStack {
                    instructionsView
                        .padding(.top, 60)
                    Spacer()
                }

                // Dimension label near selection
                if let rect = selectionRect, rect.width > 10 && rect.height > 10 {
                    dimensionLabel(for: rect)
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
                    .onEnded { value in
                        if let rect = selectionRect, rect.width >= 10 && rect.height >= 10 {
                            // ScreenCaptureKit uses top-left origin (same as SwiftUI)
                            // sourceRect is relative to the display, so use coordinates directly
                            let captureRect = NSRect(
                                x: rect.minX,
                                y: rect.minY,
                                width: rect.width,
                                height: rect.height
                            )
                            onCapture(captureRect)
                        }
                        // Reset selection
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
            .onAppear {
                // Initialize mouse position to current location
                let mouseLocation = NSEvent.mouseLocation
                // Convert screen coordinates to view coordinates
                let viewX = mouseLocation.x - screenFrame.minX
                let viewY = screenFrame.height - (mouseLocation.y - screenFrame.minY)
                mousePosition = CGPoint(x: viewX, y: viewY)
            }
        }
    }

    var instructionsView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 14))
                Text("Drag to select region")
                    .font(.system(size: 13, weight: .medium))
            }

            Text("|")
                .foregroundStyle(.white.opacity(0.3))

            HStack(spacing: 6) {
                Text("ESC")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(4)
                Text("Cancel")
                    .font(.system(size: 13))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    @ViewBuilder
    func dimensionLabel(for rect: NSRect) -> some View {
        let text = "\(Int(rect.width)) x \(Int(rect.height))"
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
            .position(
                x: rect.midX,
                y: rect.maxY + 20
            )
    }
}

struct SelectionOverlay: View {
    let selectionRect: NSRect
    let screenSize: CGSize

    var body: some View {
        Canvas { context, size in
            // Draw the dark overlay with a cutout for the selection
            var path = Path()
            path.addRect(CGRect(origin: .zero, size: size))

            // Create the cutout rectangle
            let cutout = Path(CGRect(
                x: selectionRect.minX,
                y: selectionRect.minY,
                width: selectionRect.width,
                height: selectionRect.height
            ))

            // Fill with dark color, using evenOdd to create cutout
            path.addPath(cutout)
            context.fill(path, with: .color(.black.opacity(0.4)), style: FillStyle(eoFill: true))

            // Draw selection border
            context.stroke(
                cutout,
                with: .color(.white),
                lineWidth: 2
            )

            // Draw corner handles
            let handleSize: CGFloat = 8
            let corners = [
                CGPoint(x: selectionRect.minX, y: selectionRect.minY),
                CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
                CGPoint(x: selectionRect.minX, y: selectionRect.maxY),
                CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)
            ]

            for corner in corners {
                let handleRect = CGRect(
                    x: corner.x - handleSize / 2,
                    y: corner.y - handleSize / 2,
                    width: handleSize,
                    height: handleSize
                )
                context.fill(Path(handleRect), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }
}

struct CrosshairView: View {
    let position: CGPoint
    let screenSize: CGSize

    var body: some View {
        Canvas { context, size in
            // Vertical line
            var vLine = Path()
            vLine.move(to: CGPoint(x: position.x, y: 0))
            vLine.addLine(to: CGPoint(x: position.x, y: size.height))
            context.stroke(vLine, with: .color(.white.opacity(0.5)), lineWidth: 1)

            // Horizontal line
            var hLine = Path()
            hLine.move(to: CGPoint(x: 0, y: position.y))
            hLine.addLine(to: CGPoint(x: size.width, y: position.y))
            context.stroke(hLine, with: .color(.white.opacity(0.5)), lineWidth: 1)

            // Center crosshair indicator
            let centerSize: CGFloat = 20
            var centerCross = Path()

            // Horizontal part of center cross
            centerCross.move(to: CGPoint(x: position.x - centerSize / 2, y: position.y))
            centerCross.addLine(to: CGPoint(x: position.x + centerSize / 2, y: position.y))

            // Vertical part of center cross
            centerCross.move(to: CGPoint(x: position.x, y: position.y - centerSize / 2))
            centerCross.addLine(to: CGPoint(x: position.x, y: position.y + centerSize / 2))

            context.stroke(centerCross, with: .color(.white), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}
