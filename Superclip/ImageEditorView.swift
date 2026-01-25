//
//  ImageEditorView.swift
//  Superclip
//

import SwiftUI
import AppKit

struct ImageEditorView: View {
    let originalImage: NSImage
    let clipboardManager: ClipboardManager
    let onDismiss: () -> Void
    
    @State private var editedImage: NSImage
    @State private var rotation: Double = 0
    @State private var scale: Double = 100
    @State private var isFlippedHorizontally: Bool = false
    @State private var isFlippedVertically: Bool = false
    @State private var isCropping: Bool = false
    @State private var cropRect: CGRect = .zero
    @State private var showingSaveConfirmation: Bool = false
    
    // Crop state
    @State private var cropStart: CGPoint = .zero
    @State private var cropEnd: CGPoint = .zero
    @State private var isDraggingCrop: Bool = false
    
    init(originalImage: NSImage, clipboardManager: ClipboardManager, onDismiss: @escaping () -> Void) {
        self.originalImage = originalImage
        self.clipboardManager = clipboardManager
        self.onDismiss = onDismiss
        self._editedImage = State(initialValue: originalImage)
    }
    
    var imageDimensions: String {
        let width = Int(editedImage.size.width)
        let height = Int(editedImage.size.height)
        return "\(width) × \(height)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 12))
                    Text("Image Editor")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // Reset button
                Button {
                    resetEdits()
                } label: {
                    Text("Reset")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))
            
            // Image preview area
            GeometryReader { geometry in
                ZStack {
                    // Checkerboard background for transparency
                    CheckerboardBackground()
                    
                    // The image
                    Image(nsImage: editedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(x: isFlippedHorizontally ? -1 : 1, y: isFlippedVertically ? -1 : 1)
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(scale / 100)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Crop overlay
                    if isCropping {
                        CropOverlayView(
                            cropStart: $cropStart,
                            cropEnd: $cropEnd,
                            isDragging: $isDraggingCrop,
                            geometry: geometry
                        )
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
            
            // Tools toolbar
            VStack(spacing: 12) {
                // Tool buttons
                HStack(spacing: 16) {
                    // Rotate tools
                    HStack(spacing: 8) {
                        ToolButton(icon: "rotate.left", label: "Rotate Left") {
                            rotation -= 90
                        }
                        
                        ToolButton(icon: "rotate.right", label: "Rotate Right") {
                            rotation += 90
                        }
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Flip tools
                    HStack(spacing: 8) {
                        ToolButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", label: "Flip H", isActive: isFlippedHorizontally) {
                            isFlippedHorizontally.toggle()
                        }
                        
                        ToolButton(icon: "arrow.up.and.down.righttriangle.up.righttriangle.down", label: "Flip V", isActive: isFlippedVertically) {
                            isFlippedVertically.toggle()
                        }
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Crop tool
                    ToolButton(icon: "crop", label: "Crop", isActive: isCropping) {
                        isCropping.toggle()
                        if !isCropping {
                            applyCrop()
                        }
                    }
                    
                    Spacer()
                    
                    // Scale slider
                    HStack(spacing: 8) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        Slider(value: $scale, in: 25...200, step: 5)
                            .frame(width: 100)
                        
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        Text("\(Int(scale))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.2))
            
            // Footer
            HStack {
                Text(imageDimensions)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Copy edited image button
                Button {
                    copyEditedImageToClipboard()
                    showingSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingSaveConfirmation = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showingSaveConfirmation ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 10))
                        Text(showingSaveConfirmation ? "Copied!" : "Copy to Clipboard")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(showingSaveConfirmation ? Color.green : Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: showingSaveConfirmation)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func resetEdits() {
        rotation = 0
        scale = 100
        isFlippedHorizontally = false
        isFlippedVertically = false
        isCropping = false
        editedImage = originalImage
    }
    
    private func applyCrop() {
        // Apply crop if we have a valid selection
        guard cropStart != cropEnd else { return }
        
        // For now, just reset the crop state
        // Full crop implementation would require converting coordinates
        cropStart = .zero
        cropEnd = .zero
    }
    
    private func copyEditedImageToClipboard() {
        // Create a new image with transformations applied
        let transformedImage = applyTransformations()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([transformedImage])
    }
    
    private func applyTransformations() -> NSImage {
        let size = originalImage.size
        
        // Calculate the bounding size after rotation
        let radians = rotation * .pi / 180
        let rotatedWidth = abs(size.width * cos(radians)) + abs(size.height * sin(radians))
        let rotatedHeight = abs(size.width * sin(radians)) + abs(size.height * cos(radians))
        let rotatedSize = NSSize(width: rotatedWidth, height: rotatedHeight)
        
        let newImage = NSImage(size: rotatedSize)
        newImage.lockFocus()
        
        let transform = NSAffineTransform()
        transform.translateX(by: rotatedSize.width / 2, yBy: rotatedSize.height / 2)
        transform.rotate(byDegrees: CGFloat(rotation))
        transform.scaleX(by: isFlippedHorizontally ? -1 : 1, yBy: isFlippedVertically ? -1 : 1)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        
        originalImage.draw(in: NSRect(origin: .zero, size: size))
        
        newImage.unlockFocus()
        
        return newImage
    }
}

struct ToolButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.7))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.5))
            }
            .frame(width: 50, height: 44)
            .background(isActive ? Color.blue.opacity(0.5) : Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

struct CheckerboardBackground: View {
    let squareSize: CGFloat = 10
    
    var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            
            for row in 0..<rows {
                for col in 0..<columns {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? Color(white: 0.15) : Color(white: 0.1))
                    )
                }
            }
        }
    }
}

struct CropOverlayView: View {
    @Binding var cropStart: CGPoint
    @Binding var cropEnd: CGPoint
    @Binding var isDragging: Bool
    let geometry: GeometryProxy
    
    var cropRect: CGRect {
        let minX = min(cropStart.x, cropEnd.x)
        let minY = min(cropStart.y, cropEnd.y)
        let maxX = max(cropStart.x, cropEnd.x)
        let maxY = max(cropStart.y, cropEnd.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    var body: some View {
        ZStack {
            // Dimmed overlay outside crop area
            if isDragging || cropRect.width > 0 {
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .overlay(
                                Rectangle()
                                    .frame(width: cropRect.width, height: cropRect.height)
                                    .position(x: cropRect.midX, y: cropRect.midY)
                                    .blendMode(.destinationOut)
                            )
                    )
                
                // Crop rectangle border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                
                // Corner handles
                ForEach([
                    CGPoint(x: cropRect.minX, y: cropRect.minY),
                    CGPoint(x: cropRect.maxX, y: cropRect.minY),
                    CGPoint(x: cropRect.minX, y: cropRect.maxY),
                    CGPoint(x: cropRect.maxX, y: cropRect.maxY)
                ], id: \.x) { corner in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .position(corner)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        cropStart = value.startLocation
                        isDragging = true
                    }
                    cropEnd = value.location
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}
