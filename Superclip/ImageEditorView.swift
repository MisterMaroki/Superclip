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
        ZStack(alignment: .top) {
            // Main content VStack
            VStack(spacing: 0) {
                // Spacer for header height
                Color.clear
                    .frame(height: 48)
                
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
                                imageSize: editedImage.size,
                                viewSize: geometry.size,
                                onCropConfirmed: { normalizedRect in
                                    performCrop(normalizedRect: normalizedRect)
                                }
                            )
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
                .clipped()
                
                // Tools toolbar
                VStack(spacing: 12) {
                    // Tool buttons
                    HStack(spacing: 16) {
                        // Rotate tools
                        HStack(spacing: 8) {
                            ToolButton(icon: "rotate.left", label: "Rotate Left") {
                                applyRotation(degrees: -90)
                            }
                            
                            ToolButton(icon: "rotate.right", label: "Rotate Right") {
                                applyRotation(degrees: 90)
                            }
                        }
                        
                        Divider()
                            .frame(height: 24)
                        
                        // Flip tools
                        HStack(spacing: 8) {
                            ToolButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", label: "Flip H", isActive: isFlippedHorizontally) {
                                applyFlipHorizontal()
                            }
                            
                            ToolButton(icon: "arrow.up.and.down.righttriangle.up.righttriangle.down", label: "Flip V", isActive: isFlippedVertically) {
                                applyFlipVertical()
                            }
                        }
                        
                        Divider()
                            .frame(height: 24)
                        
                        // Crop tool
                        ToolButton(icon: "crop", label: "Crop", isActive: isCropping) {
                            if isCropping {
                                // Cancel crop mode
                                isCropping = false
                                cropStart = .zero
                                cropEnd = .zero
                            } else {
                                isCropping = true
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
            
            // Header - highest z-index, always on top
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
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.5))
            .zIndex(100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        // subtle lighter shadow below
        .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: -15)
    }
    
    private func resetEdits() {
        rotation = 0
        scale = 100
        isFlippedHorizontally = false
        isFlippedVertically = false
        isCropping = false
        cropStart = .zero
        cropEnd = .zero
        editedImage = originalImage
    }
    
    private func applyRotation(degrees: Double) {
        guard let cgImage = editedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let size = editedImage.size
        let radians = degrees * .pi / 180
        
        // Calculate new size after rotation
        let newWidth = abs(size.width * cos(radians)) + abs(size.height * sin(radians))
        let newHeight = abs(size.width * sin(radians)) + abs(size.height * cos(radians))
        let newSize = NSSize(width: newWidth, height: newHeight)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        
        let transform = NSAffineTransform()
        transform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        transform.rotate(byDegrees: CGFloat(degrees))
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        
        editedImage.draw(in: NSRect(origin: .zero, size: size))
        
        newImage.unlockFocus()
        editedImage = newImage
    }
    
    private func applyFlipHorizontal() {
        isFlippedHorizontally.toggle()
        
        let size = editedImage.size
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        
        let transform = NSAffineTransform()
        transform.translateX(by: size.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        
        editedImage.draw(in: NSRect(origin: .zero, size: size))
        
        newImage.unlockFocus()
        editedImage = newImage
        isFlippedHorizontally = false  // Reset visual state since it's baked in
    }
    
    private func applyFlipVertical() {
        isFlippedVertically.toggle()
        
        let size = editedImage.size
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: size.height)
        transform.scaleX(by: 1, yBy: -1)
        transform.concat()
        
        editedImage.draw(in: NSRect(origin: .zero, size: size))
        
        newImage.unlockFocus()
        editedImage = newImage
        isFlippedVertically = false  // Reset visual state since it's baked in
    }
    
    private func performCrop(normalizedRect: CGRect) {
        let imageSize = editedImage.size
        
        // Convert normalized coordinates (0-1) to image coordinates
        let cropX = normalizedRect.origin.x * imageSize.width
        let cropY = normalizedRect.origin.y * imageSize.height
        let cropWidth = normalizedRect.width * imageSize.width
        let cropHeight = normalizedRect.height * imageSize.height
        
        // Ensure we have a valid crop area
        guard cropWidth > 1 && cropHeight > 1 else {
            cropStart = .zero
            cropEnd = .zero
            isCropping = false
            return
        }
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        // Create cropped image
        guard let cgImage = editedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            cropStart = .zero
            cropEnd = .zero
            isCropping = false
            return
        }
        
        // Convert to CGImage coordinates (flipped Y)
        let cgCropRect = CGRect(
            x: cropRect.origin.x,
            y: imageSize.height - cropRect.origin.y - cropRect.height,
            width: cropRect.width,
            height: cropRect.height
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cgCropRect) else {
            cropStart = .zero
            cropEnd = .zero
            isCropping = false
            return
        }
        
        let croppedImage = NSImage(cgImage: croppedCGImage, size: NSSize(width: cropRect.width, height: cropRect.height))
        editedImage = croppedImage
        
        // Reset crop state
        cropStart = .zero
        cropEnd = .zero
        isCropping = false
    }
    
    private func copyEditedImageToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([editedImage])
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
    let imageSize: NSSize
    let viewSize: CGSize
    let onCropConfirmed: (CGRect) -> Void
    
    var cropRect: CGRect {
        let minX = min(cropStart.x, cropEnd.x)
        let minY = min(cropStart.y, cropEnd.y)
        let maxX = max(cropStart.x, cropEnd.x)
        let maxY = max(cropStart.y, cropEnd.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // Calculate the image frame within the view (aspectRatio .fit)
    var imageFrame: CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var displayWidth: CGFloat
        var displayHeight: CGFloat
        
        if imageAspect > viewAspect {
            // Image is wider than view - fit to width
            displayWidth = viewSize.width
            displayHeight = viewSize.width / imageAspect
        } else {
            // Image is taller than view - fit to height
            displayHeight = viewSize.height
            displayWidth = viewSize.height * imageAspect
        }
        
        let x = (viewSize.width - displayWidth) / 2
        let y = (viewSize.height - displayHeight) / 2
        
        return CGRect(x: x, y: y, width: displayWidth, height: displayHeight)
    }
    
    var hasValidCrop: Bool {
        cropRect.width > 10 && cropRect.height > 10
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
                
                // Rule of thirds grid
                if cropRect.width > 30 && cropRect.height > 30 {
                    Path { path in
                        // Vertical lines
                        path.move(to: CGPoint(x: cropRect.minX + cropRect.width / 3, y: cropRect.minY))
                        path.addLine(to: CGPoint(x: cropRect.minX + cropRect.width / 3, y: cropRect.maxY))
                        path.move(to: CGPoint(x: cropRect.minX + cropRect.width * 2 / 3, y: cropRect.minY))
                        path.addLine(to: CGPoint(x: cropRect.minX + cropRect.width * 2 / 3, y: cropRect.maxY))
                        // Horizontal lines
                        path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + cropRect.height / 3))
                        path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + cropRect.height / 3))
                        path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + cropRect.height * 2 / 3))
                        path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + cropRect.height * 2 / 3))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                }
                
                // Corner handles
                ForEach(Array([
                    CGPoint(x: cropRect.minX, y: cropRect.minY),
                    CGPoint(x: cropRect.maxX, y: cropRect.minY),
                    CGPoint(x: cropRect.minX, y: cropRect.maxY),
                    CGPoint(x: cropRect.maxX, y: cropRect.maxY)
                ].enumerated()), id: \.offset) { _, corner in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .position(corner)
                }
                
                // Confirm button
                if hasValidCrop && !isDragging {
                    Button {
                        confirmCrop()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Apply Crop")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .position(x: cropRect.midX, y: cropRect.maxY + 30)
                }
            }
            
            // Instructions when no crop yet
            if cropRect.width == 0 && !isDragging {
                VStack(spacing: 8) {
                    Image(systemName: "crop")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Drag to select crop area")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
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
    
    private func confirmCrop() {
        let imgFrame = imageFrame
        
        // Clamp crop rect to image bounds
        let clampedMinX = max(cropRect.minX, imgFrame.minX)
        let clampedMinY = max(cropRect.minY, imgFrame.minY)
        let clampedMaxX = min(cropRect.maxX, imgFrame.maxX)
        let clampedMaxY = min(cropRect.maxY, imgFrame.maxY)
        
        // Convert screen coordinates to normalized image coordinates (0-1)
        let normalizedX = (clampedMinX - imgFrame.minX) / imgFrame.width
        let normalizedY = (clampedMinY - imgFrame.minY) / imgFrame.height
        let normalizedWidth = (clampedMaxX - clampedMinX) / imgFrame.width
        let normalizedHeight = (clampedMaxY - clampedMinY) / imgFrame.height
        
        let normalizedRect = CGRect(
            x: max(0, min(1, normalizedX)),
            y: max(0, min(1, normalizedY)),
            width: max(0, min(1, normalizedWidth)),
            height: max(0, min(1, normalizedHeight))
        )
        
        onCropConfirmed(normalizedRect)
    }
}
