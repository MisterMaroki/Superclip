//
//  ImageAnnotationEditorView.swift
//  Superclip
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImageAnnotationEditorView: View {
  let originalImage: NSImage
  let pngData: Data
  let onSave: (NSImage, Data) -> Void
  let onDismiss: () -> Void

  @StateObject private var annotationState = AnnotationState()

  // Image transforms
  @State private var editedImage: NSImage
  @State private var rotation: Double = 0
  @State private var scale: Double = 100
  @State private var isFlippedHorizontally = false
  @State private var isFlippedVertically = false

  // Crop
  @State private var isCropping = false
  @State private var cropStart: CGPoint = .zero
  @State private var cropEnd: CGPoint = .zero
  @State private var isDraggingCrop = false

  // Export
  @State private var showingSaveConfirmation = false
  @State private var showingExportConfirmation = false

  // Text editing
  @State private var textInputValue = ""

  // Precomputed blur
  @State private var precomputedBlurImage: NSImage?
  @State private var blurPrecomputeWorkItem: DispatchWorkItem?

  // Committed blurs baked at their stored radius/style (preview == export)
  @State private var committedBlurImage: NSImage?
  @State private var committedBlurWorkItem: DispatchWorkItem?

  // Pinch-to-zoom anchor
  @State private var magnifyAnchorScale: Double = 1.0

  // Pan offset
  @State private var panOffset: CGSize = .zero
  @State private var panDragOffset: CGSize = .zero

  // Annotation tool color presets
  private let colorPresets: [Color] = [
    .red, .orange, .yellow, .green, .blue, .purple, .white, .black,
  ]

  /// Pixel-normalized copy of the original — see `pixelNormalized(_:pngData:)`.
  private let baseImage: NSImage

  init(
    originalImage: NSImage,
    pngData: Data,
    onSave: @escaping (NSImage, Data) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.originalImage = originalImage
    self.pngData = pngData
    self.onSave = onSave
    self.onDismiss = onDismiss
    let normalized = Self.pixelNormalized(originalImage, pngData: pngData)
    self.baseImage = normalized
    self._editedImage = State(initialValue: normalized)
  }

  /// Returns an NSImage whose point size equals its pixel size (72 dpi).
  /// DPI-tagged images (e.g. macOS screenshots at 144 dpi) otherwise have
  /// point ≠ pixel dimensions, which corrupts every rect computed against
  /// `image.size` and then applied to the CGImage: blur redaction regions,
  /// crop rects, and flatten output resolution.
  private static func pixelNormalized(_ image: NSImage, pngData: Data) -> NSImage {
    if let source = CGImageSourceCreateWithData(pngData as CFData, nil),
      let cg = CGImageSourceCreateImageAtIndex(source, 0, nil)
    {
      return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
    if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
      return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
    return image
  }

  /// Render into an explicit bitmap context of exact pixel dimensions.
  /// `NSImage.lockFocus()` rasterizes at the main display's backing scale,
  /// which halves or doubles exported resolution depending on the screen.
  private static func renderBitmapCG(
    width: Int, height: Int, draw: (CGContext) -> Void
  ) -> CGImage? {
    guard width > 0, height > 0,
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()
  }

  var imageDimensions: String {
    let width = Int(editedImage.size.width)
    let height = Int(editedImage.size.height)
    return "\(width) \u{00D7} \(height)"
  }

  var body: some View {
    VStack(spacing: 0) {
      headerBar
      canvasArea
      toolOptionsBar
      mainToolbar
      footerBar
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Brand.white)
    .clipShape(Rectangle())
    .overlay(
      Rectangle()
        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
    )
    .onChange(of: annotationState.selectedTool) { newTool in
      if newTool == .blur {
        precomputeBlur()
      }
      if newTool != .crop && isCropping {
        isCropping = false
        cropStart = .zero
        cropEnd = .zero
      }
    }
    .onChange(of: annotationState.blurRadius) { _ in
      if annotationState.selectedTool == .blur {
        precomputeBlur()
      }
    }
    .onChange(of: annotationState.blurStyle) { _ in
      if annotationState.selectedTool == .blur {
        precomputeBlur()
      }
    }
    // Rebake committed blurs whenever the set of blur annotations changes
    // (commit, move, resize, delete, undo/redo)
    .onChange(of: annotationState.annotations.filter { $0.tool == .blur }) { _ in
      recomputeCommittedBlurs()
    }
    // Listen for keyboard shortcut notifications from the panel
    .onReceive(NotificationCenter.default.publisher(for: .imageEditorUndo)) { _ in
      annotationState.undo()
    }
    .onReceive(NotificationCenter.default.publisher(for: .imageEditorRedo)) { _ in
      annotationState.redo()
    }
    .onReceive(NotificationCenter.default.publisher(for: .imageEditorSave)) { _ in
      performSave()
    }
    .onReceive(NotificationCenter.default.publisher(for: .imageEditorDeleteSelected)) { _ in
      annotationState.deleteSelected()
    }
    .onReceive(NotificationCenter.default.publisher(for: .imageEditorEscape)) { _ in
      if annotationState.selectedAnnotationId != nil {
        annotationState.selectedAnnotationId = nil
      } else if annotationState.isEditingText {
        annotationState.isEditingText = false
        annotationState.textPlacementPoint = nil
        textInputValue = ""
      } else if isCropping {
        isCropping = false
        cropStart = .zero
        cropEnd = .zero
      } else {
        onDismiss()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .imageEditorSelectTool)) { notification in
      if let toolIndex = notification.userInfo?["toolIndex"] as? Int {
        let tools: [AnnotationTool] = [.select, .pencil, .line, .arrow, .rectangle, .ellipse, .text, .stepCounter, .highlighter, .blur]
        if toolIndex >= 0 && toolIndex < tools.count {
          annotationState.selectedTool = tools[toolIndex]
        }
      }
    }
  }

  // MARK: - Header

  private var headerBar: some View {
    HStack(spacing: 12) {
      Button {
        onDismiss()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 16))
          .foregroundStyle(Brand.gray600)
      }
      .buttonStyle(.plain)

      HStack(spacing: 6) {
        Image(systemName: "photo")
          .font(.system(size: 12))
        Text("Image Editor")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.primary)
      }

      Spacer()

      // Undo / Redo
      HStack(spacing: 4) {
        Button {
          annotationState.undo()
        } label: {
          Image(systemName: "arrow.uturn.backward")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(annotationState.canUndo ? Color.primary : Brand.gray600)
            .frame(width: 28, height: 28)
            .background(Color.primary.opacity(0.08))
        }
        .buttonStyle(.plain)
        .disabled(!annotationState.canUndo)
        .help("Undo (Cmd+Z)")

        Button {
          annotationState.redo()
        } label: {
          Image(systemName: "arrow.uturn.forward")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(annotationState.canRedo ? Color.primary : Brand.gray600)
            .frame(width: 28, height: 28)
            .background(Color.primary.opacity(0.08))
        }
        .buttonStyle(.plain)
        .disabled(!annotationState.canRedo)
        .help("Redo (Cmd+Shift+Z)")
      }

      // Reset
      Button {
        resetAll()
      } label: {
        Text("Reset")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Brand.gray600)
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
          .background(Color.primary.opacity(0.1))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(WindowDragArea())
    .background(Brand.gray100)
  }

  // MARK: - Canvas

  private var currentPanOffset: CGSize {
    CGSize(
      width: panOffset.width + panDragOffset.width,
      height: panOffset.height + panDragOffset.height
    )
  }

  private var canvasArea: some View {
    GeometryReader { geometry in
      ZStack {
        CheckerboardBackground()

        // The base image with transforms
        Image(nsImage: editedImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .scaleEffect(x: isFlippedHorizontally ? -1 : 1, y: isFlippedVertically ? -1 : 1)
          .rotationEffect(.degrees(rotation))
          .scaleEffect(scale / 100)
          .offset(currentPanOffset)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

        // Annotation canvas overlay
        if !isCropping {
          AnnotationCanvasView(
            state: annotationState,
            imageFrame: computeImageFrameUnscaled(in: geometry.size),
            blurPreviewNSImage: precomputedBlurImage,
            committedBlurNSImage: committedBlurImage,
            onTextPlacement: { _ in
              textInputValue = ""
            }
          )
          .scaleEffect(scale / 100)
          .offset(currentPanOffset)
        }

        // Text input overlay
        if annotationState.isEditingText, let placement = annotationState.textPlacementPoint {
          textInputOverlay(placement: placement, in: geometry.size)
        }

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
      // Pinch-to-zoom
      .simultaneousGesture(
        MagnificationGesture()
          .onChanged { value in
            let newScale = magnifyAnchorScale * value * 100
            scale = min(max(newScale, 25), 200)
          }
          .onEnded { _ in
            magnifyAnchorScale = scale / 100
          }
      )
      // Pan via trackpad scroll / scroll wheel
      .overlay(
        ScrollWheelPanView { dx, dy in
          panOffset = CGSize(
            width: panOffset.width + dx,
            height: panOffset.height + dy
          )
        }
      )
    }
    .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
    .clipped()
  }

  /// Image frame with zoom scale applied — used for text input overlay positioning.
  private func computeImageFrame(in viewSize: CGSize) -> CGRect {
    return computeImageFrame(in: viewSize, scaleFactor: scale / 100)
  }

  /// Image frame at 100% zoom — used for annotation canvas drawing so the
  /// Canvas never needs to draw outside its own bounds (visual zoom is applied
  /// via `.scaleEffect` instead).
  private func computeImageFrameUnscaled(in viewSize: CGSize) -> CGRect {
    return computeImageFrame(in: viewSize, scaleFactor: 1.0)
  }

  private func computeImageFrame(in viewSize: CGSize, scaleFactor: CGFloat) -> CGRect {
    let imageSize = editedImage.size
    guard imageSize.width > 0, imageSize.height > 0 else {
      return .zero
    }

    let imageAspect = imageSize.width / imageSize.height
    let viewAspect = viewSize.width / viewSize.height

    var displayWidth: CGFloat
    var displayHeight: CGFloat

    if imageAspect > viewAspect {
      displayWidth = viewSize.width
      displayHeight = viewSize.width / imageAspect
    } else {
      displayHeight = viewSize.height
      displayWidth = viewSize.height * imageAspect
    }

    displayWidth *= scaleFactor
    displayHeight *= scaleFactor

    let x = (viewSize.width - displayWidth) / 2
    let y = (viewSize.height - displayHeight) / 2

    return CGRect(x: x, y: y, width: displayWidth, height: displayHeight)
  }

  @ViewBuilder
  private func textInputOverlay(placement: CGPoint, in viewSize: CGSize) -> some View {
    let frame = computeImageFrame(in: viewSize)
    let viewX = frame.origin.x + placement.x * frame.width
    let viewY = frame.origin.y + placement.y * frame.height

    TextField("Type here...", text: $textInputValue, onCommit: {
      commitTextAnnotation(at: placement)
    })
    .textFieldStyle(.plain)
    .font(.system(size: annotationState.fontSize))
    .foregroundColor(annotationState.selectedColor)
    .padding(4)
    .background(Color.black.opacity(0.4))
    .frame(width: 200)
    .position(x: viewX + 100, y: viewY + 12)
  }

  private func commitTextAnnotation(at normalizedPoint: CGPoint) {
    guard !textInputValue.isEmpty else {
      annotationState.isEditingText = false
      annotationState.textPlacementPoint = nil
      return
    }
    let annotation = Annotation(
      tool: .text,
      color: annotationState.selectedColor,
      strokeWidth: annotationState.strokeWidth,
      points: [normalizedPoint],
      textContent: textInputValue,
      fontSize: annotationState.fontSize
    )
    annotationState.commitAnnotation(annotation)
    annotationState.isEditingText = false
    annotationState.textPlacementPoint = nil
    textInputValue = ""
  }

  // MARK: - Tool Options Bar

  private var toolOptionsBar: some View {
    HStack(spacing: 12) {
      // Color presets
      HStack(spacing: 4) {
        ForEach(colorPresets, id: \.self) { color in
          Button {
            annotationState.selectedColor = color
          } label: {
            Circle()
              .fill(color)
              .frame(width: 18, height: 18)
              .overlay(
                Circle()
                  .stroke(
                    annotationState.selectedColor == color ? Color.white : Color.clear,
                    lineWidth: 2
                  )
              )
          }
          .buttonStyle(.plain)
        }

        ColorPicker("", selection: $annotationState.selectedColor)
          .labelsHidden()
          .frame(width: 24, height: 24)
      }

      Divider()
        .frame(height: 20)

      // Stroke width slider
      if annotationState.selectedTool != .text && annotationState.selectedTool != .blur
        && annotationState.selectedTool != .select
        && annotationState.selectedTool != .crop
      {
        HStack(spacing: 6) {
          Image(systemName: "lineweight")
            .font(.system(size: 10))
            .foregroundStyle(Brand.gray600)
          Slider(value: $annotationState.strokeWidth, in: 1...20, step: 1)
            .frame(width: 80)
          Text("\(Int(annotationState.strokeWidth))")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Brand.gray600)
            .frame(width: 20)
        }
      }

      // Fill mode toggle (shapes)
      if annotationState.selectedTool == .rectangle || annotationState.selectedTool == .ellipse {
        Divider()
          .frame(height: 20)

        HStack(spacing: 4) {
          fillModeButton(.stroke, icon: "square", label: "Stroke")
          fillModeButton(.fill, icon: "square.fill", label: "Fill")
          fillModeButton(.both, icon: "square.inset.filled", label: "Both")
        }
      }

      // Font size (text)
      if annotationState.selectedTool == .text {
        Divider()
          .frame(height: 20)

        HStack(spacing: 6) {
          Image(systemName: "textformat.size")
            .font(.system(size: 10))
            .foregroundStyle(Brand.gray600)
          Slider(value: $annotationState.fontSize, in: 8...72, step: 2)
            .frame(width: 80)
          Text("\(Int(annotationState.fontSize))")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Brand.gray600)
            .frame(width: 24)
        }
      }

      // Step counter info
      if annotationState.selectedTool == .stepCounter {
        Divider()
          .frame(height: 20)

        HStack(spacing: 6) {
          Image(systemName: "number.circle")
            .font(.system(size: 10))
            .foregroundStyle(Brand.gray600)
          Text("Next: #\(annotationState.nextStepNumber)")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Brand.gray600)
        }
      }

      // Blur options
      if annotationState.selectedTool == .blur {
        Divider()
          .frame(height: 20)

        HStack(spacing: 6) {
          Button {
            annotationState.blurStyle = .gaussian
          } label: {
            Text("Gaussian")
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(annotationState.blurStyle == .gaussian ? Brand.white : Brand.gray600)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(annotationState.blurStyle == .gaussian ? Brand.black : Color.primary.opacity(0.1))
          }
          .buttonStyle(.plain)

          Button {
            annotationState.blurStyle = .pixelate
          } label: {
            Text("Pixelate")
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(annotationState.blurStyle == .pixelate ? Brand.white : Brand.gray600)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(annotationState.blurStyle == .pixelate ? Brand.black : Color.primary.opacity(0.1))
          }
          .buttonStyle(.plain)

          Slider(value: $annotationState.blurRadius, in: 2...30, step: 1)
            .frame(width: 60)
          Text("\(Int(annotationState.blurRadius))")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Brand.gray600)
            .frame(width: 20)
        }
      }

      Spacer()

      // Delete selected annotation
      if annotationState.selectedAnnotationId != nil {
        Button {
          annotationState.deleteSelected()
        } label: {
          Image(systemName: "trash")
            .font(.system(size: 11))
            .foregroundStyle(.red)
            .frame(width: 28, height: 28)
            .background(Color.red.opacity(0.15))
        }
        .buttonStyle(.plain)
        .help("Delete selected annotation")
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Brand.gray100)
  }

  private func fillModeButton(_ mode: FillMode, icon: String, label: String) -> some View {
    Button {
      annotationState.fillMode = mode
    } label: {
      Image(systemName: icon)
        .font(.system(size: 12))
        .foregroundStyle(annotationState.fillMode == mode ? Brand.white : Brand.gray600)
        .frame(width: 28, height: 28)
        .background(annotationState.fillMode == mode ? Brand.black : Color.primary.opacity(0.08))
    }
    .buttonStyle(.plain)
    .help(label)
  }

  // MARK: - Main Toolbar

  private var mainToolbar: some View {
    HStack(spacing: 12) {
      // Annotation tools
      HStack(spacing: 4) {
        ForEach(
          [AnnotationTool.select, .pencil, .line, .arrow, .rectangle, .ellipse, .text, .stepCounter, .highlighter, .blur],
          id: \.self
        ) { tool in
          annotationToolButton(tool)
        }
      }

      Divider()
        .frame(height: 28)

      // Transform tools
      HStack(spacing: 4) {
        ToolButton(icon: "rotate.left", label: "Rot L") {
          applyRotation(degrees: -90)
        }
        ToolButton(icon: "rotate.right", label: "Rot R") {
          applyRotation(degrees: 90)
        }
        ToolButton(
          icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", label: "Flip H",
          isActive: isFlippedHorizontally
        ) {
          applyFlipHorizontal()
        }
        ToolButton(
          icon: "arrow.up.and.down.righttriangle.up.righttriangle.down", label: "Flip V",
          isActive: isFlippedVertically
        ) {
          applyFlipVertical()
        }
        ToolButton(icon: "crop", label: "Crop", isActive: isCropping) {
          toggleCrop()
        }
      }

      Spacer()

      // Zoom slider
      HStack(spacing: 8) {
        Image(systemName: "minus.magnifyingglass")
          .font(.system(size: 11))
          .foregroundStyle(Brand.gray600)

        Slider(value: $scale, in: 25...200, step: 5)
          .frame(width: 100)

        Image(systemName: "plus.magnifyingglass")
          .font(.system(size: 11))
          .foregroundStyle(Brand.gray600)

        Text("\(Int(scale))%")
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(Brand.gray600)
          .frame(width: 40)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Brand.gray100)
  }

  private func annotationToolButton(_ tool: AnnotationTool) -> some View {
    let isActive = annotationState.selectedTool == tool
    return Button {
      annotationState.selectedTool = tool
    } label: {
      VStack(spacing: 2) {
        Image(systemName: tool.icon)
          .font(.system(size: 14))
          .foregroundStyle(isActive ? Brand.white : .primary.opacity(0.7))
        Text(tool.label)
          .font(.system(size: 8))
          .foregroundStyle(isActive ? Brand.white : .primary.opacity(0.5))
      }
      .frame(width: 42, height: 38)
      .background(isActive ? Brand.black : Color.primary.opacity(0.05))
    }
    .buttonStyle(.plain)
    .help(tool.label)
  }

  // MARK: - Footer

  private var footerBar: some View {
    HStack {
      Text(imageDimensions)
        .font(.system(size: 11))
        .foregroundStyle(Brand.gray600)

      if !annotationState.annotations.isEmpty {
        Text("\u{2022} \(annotationState.annotations.count) annotations")
          .font(.system(size: 11))
          .foregroundStyle(Brand.gray600)
      }

      Spacer()

      // Copy to Clipboard
      Button {
        performSave()
      } label: {
        HStack(spacing: 4) {
          Image(systemName: showingSaveConfirmation ? "checkmark" : "doc.on.clipboard")
            .font(.system(size: 10))
          Text(showingSaveConfirmation ? "Copied!" : "Copy")
            .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(showingSaveConfirmation ? Color.green : Brand.black)
      }
      .buttonStyle(.plain)
      .animation(.easeInOut(duration: 0.2), value: showingSaveConfirmation)

      // Save PNG
      Button {
        exportPNG()
      } label: {
        HStack(spacing: 4) {
          Image(systemName: showingExportConfirmation ? "checkmark" : "square.and.arrow.up")
            .font(.system(size: 10))
          Text(showingExportConfirmation ? "Saved!" : "Save PNG")
            .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(showingExportConfirmation ? Color.green : Color.primary.opacity(0.15))
      }
      .buttonStyle(.plain)
      .animation(.easeInOut(duration: 0.2), value: showingExportConfirmation)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Brand.gray100)
  }

  // MARK: - Actions

  private func performSave() {
    if let (image, data) = flattenImage() {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.writeObjects([image])
      if let pngData = data {
        pasteboard.setData(pngData, forType: .png)
      }
      onSave(image, data ?? self.pngData)
      onDismiss()
    }
  }

  private func resetAll() {
    rotation = 0
    scale = 100
    magnifyAnchorScale = 1.0
    panOffset = .zero
    panDragOffset = .zero
    isFlippedHorizontally = false
    isFlippedVertically = false
    isCropping = false
    cropStart = .zero
    cropEnd = .zero
    editedImage = baseImage
    annotationState.reset()
    precomputedBlurImage = nil
  }

  private func toggleCrop() {
    if isCropping {
      isCropping = false
      cropStart = .zero
      cropEnd = .zero
    } else {
      isCropping = true
      annotationState.selectedTool = .crop
    }
  }

  private func precomputeBlur() {
    // Debounce + cancel: the radius slider fires per tick, and each compute
    // renders a full-resolution blurred copy. Without coalescing, one slider
    // drag on a 5K screenshot spawns dozens of concurrent CoreImage renders.
    blurPrecomputeWorkItem?.cancel()
    let img = editedImage
    let style = annotationState.blurStyle
    let radius = annotationState.blurRadius
    let work = DispatchWorkItem {
      let blurred = BlurTool.precomputeBlurred(
        image: img,
        style: style,
        radius: radius
      )
      DispatchQueue.main.async {
        // Drop stale results that finish after the parameters changed
        guard annotationState.blurStyle == style,
          annotationState.blurRadius == radius,
          editedImage === img
        else { return }
        precomputedBlurImage = blurred
      }
    }
    blurPrecomputeWorkItem = work
    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.12, execute: work)
  }

  private func applyRotation(degrees: Double) {
    guard let cg = editedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

    let w = cg.width
    let h = cg.height
    let radians = degrees * .pi / 180

    let newWidth = Int((abs(Double(w) * CoreGraphics.cos(radians)) + abs(Double(h) * CoreGraphics.sin(radians))).rounded())
    let newHeight = Int((abs(Double(w) * CoreGraphics.sin(radians)) + abs(Double(h) * CoreGraphics.cos(radians))).rounded())

    guard let outCG = Self.renderBitmapCG(width: newWidth, height: newHeight, draw: { ctx in
      ctx.translateBy(x: CGFloat(newWidth) / 2, y: CGFloat(newHeight) / 2)
      ctx.rotate(by: CGFloat(radians))
      ctx.translateBy(x: -CGFloat(w) / 2, y: -CGFloat(h) / 2)
      ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    }) else { return }

    editedImage = NSImage(cgImage: outCG, size: NSSize(width: newWidth, height: newHeight))
    // Keep annotations glued to the content they were drawn on
    if degrees > 0 {
      annotationState.remapAllPoints { CGPoint(x: $0.y, y: 1 - $0.x) }
    } else {
      annotationState.remapAllPoints { CGPoint(x: 1 - $0.y, y: $0.x) }
    }
    refreshBlurPreviewIfNeeded()
  }

  private func applyFlipHorizontal() {
    guard let cg = editedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    let w = cg.width
    let h = cg.height

    guard let outCG = Self.renderBitmapCG(width: w, height: h, draw: { ctx in
      ctx.translateBy(x: CGFloat(w), y: 0)
      ctx.scaleBy(x: -1, y: 1)
      ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    }) else { return }

    editedImage = NSImage(cgImage: outCG, size: NSSize(width: w, height: h))
    annotationState.remapAllPoints { CGPoint(x: 1 - $0.x, y: $0.y) }
    refreshBlurPreviewIfNeeded()
  }

  private func applyFlipVertical() {
    guard let cg = editedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    let w = cg.width
    let h = cg.height

    guard let outCG = Self.renderBitmapCG(width: w, height: h, draw: { ctx in
      ctx.translateBy(x: 0, y: CGFloat(h))
      ctx.scaleBy(x: 1, y: -1)
      ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    }) else { return }

    editedImage = NSImage(cgImage: outCG, size: NSSize(width: w, height: h))
    annotationState.remapAllPoints { CGPoint(x: $0.x, y: 1 - $0.y) }
    refreshBlurPreviewIfNeeded()
  }

  /// The blur previews are snapshots of the image at compute time — refresh
  /// them after any transform so blurs don't preview stale content.
  private func refreshBlurPreviewIfNeeded() {
    if annotationState.selectedTool == .blur {
      precomputeBlur()
    }
    recomputeCommittedBlurs()
  }

  /// Bake every committed blur annotation into a preview image at its own
  /// stored radius/style — the same sequence `flattenImage` applies on
  /// export, so what the canvas shows for committed blurs is exact.
  private func recomputeCommittedBlurs() {
    committedBlurWorkItem?.cancel()
    let blurs = annotationState.annotations.filter { $0.tool == .blur }
    guard !blurs.isEmpty else {
      committedBlurImage = nil
      return
    }
    let img = editedImage
    let work = DispatchWorkItem {
      var working = img
      for blur in blurs {
        guard blur.points.count >= 2 else { continue }
        let p0 = blur.points[0]
        let p1 = blur.points[1]
        let ws = working.size
        let blurRect = CGRect(
          x: min(p0.x, p1.x) * ws.width,
          y: min(p0.y, p1.y) * ws.height,
          width: abs(p1.x - p0.x) * ws.width,
          height: abs(p1.y - p0.y) * ws.height
        )
        if let blurred = BlurTool.applyBlur(
          to: working, in: blurRect, style: blur.blurStyle, radius: blur.blurRadius
        ) {
          working = blurred
        }
      }
      let result = working
      DispatchQueue.main.async {
        guard editedImage === img,
          annotationState.annotations.filter({ $0.tool == .blur }) == blurs
        else { return }
        committedBlurImage = result
      }
    }
    committedBlurWorkItem = work
    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15, execute: work)
  }

  private func performCrop(normalizedRect: CGRect) {
    let imageSize = editedImage.size

    let cropX = normalizedRect.origin.x * imageSize.width
    let cropY = normalizedRect.origin.y * imageSize.height
    let cropWidth = normalizedRect.width * imageSize.width
    let cropHeight = normalizedRect.height * imageSize.height

    guard cropWidth > 1 && cropHeight > 1 else {
      cropStart = .zero
      cropEnd = .zero
      isCropping = false
      return
    }

    guard let cgImage = editedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      cropStart = .zero
      cropEnd = .zero
      isCropping = false
      return
    }

    let cgCropRect = CGRect(
      x: cropX,
      y: imageSize.height - cropY - cropHeight,
      width: cropWidth,
      height: cropHeight
    )

    guard let croppedCGImage = cgImage.cropping(to: cgCropRect) else {
      cropStart = .zero
      cropEnd = .zero
      isCropping = false
      return
    }

    editedImage = NSImage(
      cgImage: croppedCGImage,
      size: NSSize(width: croppedCGImage.width, height: croppedCGImage.height)
    )

    // Re-express annotation coordinates relative to the cropped region
    let cw = max(normalizedRect.width, 0.0001)
    let ch = max(normalizedRect.height, 0.0001)
    annotationState.remapAllPoints { p in
      CGPoint(x: (p.x - normalizedRect.minX) / cw, y: (p.y - normalizedRect.minY) / ch)
    }

    cropStart = .zero
    cropEnd = .zero
    isCropping = false
    refreshBlurPreviewIfNeeded()
  }

  // MARK: - Flatten & Export

  /// Composite all annotations onto the base image at full resolution.
  private func flattenImage() -> (NSImage, Data?)? {
    let imageSize = editedImage.size
    guard imageSize.width > 0, imageSize.height > 0 else { return nil }

    // Step 1: Apply blur annotations to the base image
    var workingImage = editedImage
    let blurAnnotations = annotationState.annotations.filter { $0.tool == .blur }
    for blur in blurAnnotations {
      guard blur.points.count >= 2 else { continue }
      let p0 = blur.points[0]
      let p1 = blur.points[1]
      let ws = workingImage.size
      // Normalized coords: (0,0)=top-left. BlurTool expects top-left origin rect.
      let blurRect = CGRect(
        x: min(p0.x, p1.x) * ws.width,
        y: min(p0.y, p1.y) * ws.height,
        width: abs(p1.x - p0.x) * ws.width,
        height: abs(p1.y - p0.y) * ws.height
      )
      if let blurred = BlurTool.applyBlur(
        to: workingImage,
        in: blurRect,
        style: blur.blurStyle,
        radius: blur.blurRadius
      ) {
        workingImage = blurred
      }
    }

    // Step 2: Draw non-blur annotations on top, rendering into an explicit
    // bitmap context at the image's exact pixel dimensions (lockFocus would
    // rasterize at the display's backing scale, changing output resolution).
    guard let workingCG = workingImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return (workingImage, nil) }
    let pixelWidth = workingCG.width
    let pixelHeight = workingCG.height
    let pixelSize = NSSize(width: pixelWidth, height: pixelHeight)

    let nonBlurAnnotations = annotationState.annotations.filter { $0.tool != .blur }
    guard let outCG = Self.renderBitmapCG(width: pixelWidth, height: pixelHeight, draw: { ctx in
      ctx.draw(workingCG, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
      for annotation in nonBlurAnnotations {
        renderAnnotationToCGContext(annotation, context: ctx, imageSize: pixelSize)
      }
    }) else {
      return (workingImage, nil)
    }

    let composited = NSImage(cgImage: outCG, size: pixelSize)
    let rep = NSBitmapImageRep(cgImage: outCG)
    let png = rep.representation(using: .png, properties: [:])

    return (composited, png)
  }

  private func renderAnnotationToCGContext(
    _ annotation: Annotation,
    context: CGContext,
    imageSize: NSSize
  ) {
    // NSImage lockFocus uses bottom-left origin by default.
    // Normalized (0,0) = top-left → pixel (0, height)
    let points = annotation.points.map { p in
      CGPoint(x: p.x * imageSize.width, y: (1 - p.y) * imageSize.height)
    }
    guard !points.isEmpty else { return }

    // Scale factor matching the canvas preview (which uses imageFrame.width / 500).
    // Here we use the full image width so exported annotations look identical.
    let sf = imageSize.width / 500
    let strokeW = annotation.strokeWidth * sf

    let nsColor = NSColor(annotation.color)
    context.saveGState()
    context.setAlpha(CGFloat(annotation.opacity))

    switch annotation.tool {
    case .pencil:
      guard points.count >= 2 else { break }
      context.setStrokeColor(nsColor.cgColor)
      context.setLineWidth(strokeW)
      context.setLineCap(.round)
      context.setLineJoin(.round)
      context.move(to: points[0])
      for i in 1..<points.count {
        context.addLine(to: points[i])
      }
      context.strokePath()

    case .highlighter:
      guard points.count >= 2 else { break }
      context.setStrokeColor(nsColor.cgColor)
      context.setLineWidth(strokeW * 3)
      context.setLineCap(.round)
      context.setLineJoin(.round)
      context.move(to: points[0])
      for i in 1..<points.count {
        context.addLine(to: points[i])
      }
      context.strokePath()

    case .line:
      guard points.count >= 2 else { break }
      context.setStrokeColor(nsColor.cgColor)
      context.setLineWidth(strokeW)
      context.setLineCap(.round)
      context.move(to: points[0])
      context.addLine(to: points[1])
      context.strokePath()

    case .arrow:
      guard points.count >= 2 else { break }
      let start = points[0]
      let end = points[1]
      context.setStrokeColor(nsColor.cgColor)
      context.setLineWidth(strokeW)
      context.setLineCap(.round)
      context.move(to: start)
      context.addLine(to: end)
      context.strokePath()
      // Arrowhead
      let angle = atan2(end.y - start.y, end.x - start.x)
      let headLength = max(strokeW * 4, 12 * sf)
      let headAngle: CGFloat = .pi / 6
      let p1 = CGPoint(
        x: end.x - headLength * cos(angle - headAngle),
        y: end.y - headLength * sin(angle - headAngle)
      )
      let p2 = CGPoint(
        x: end.x - headLength * cos(angle + headAngle),
        y: end.y - headLength * sin(angle + headAngle)
      )
      context.move(to: p1)
      context.addLine(to: end)
      context.addLine(to: p2)
      context.strokePath()

    case .rectangle:
      guard points.count >= 2 else { break }
      let rect = CGRect(
        x: min(points[0].x, points[1].x),
        y: min(points[0].y, points[1].y),
        width: abs(points[1].x - points[0].x),
        height: abs(points[1].y - points[0].y)
      )
      if annotation.fillMode == .fill || annotation.fillMode == .both {
        context.setFillColor(nsColor.withAlphaComponent(0.3).cgColor)
        context.fill(rect)
      }
      if annotation.fillMode == .stroke || annotation.fillMode == .both {
        context.setStrokeColor(nsColor.cgColor)
        context.setLineWidth(strokeW)
        context.stroke(rect)
      }

    case .ellipse:
      guard points.count >= 2 else { break }
      let rect = CGRect(
        x: min(points[0].x, points[1].x),
        y: min(points[0].y, points[1].y),
        width: abs(points[1].x - points[0].x),
        height: abs(points[1].y - points[0].y)
      )
      if annotation.fillMode == .fill || annotation.fillMode == .both {
        context.setFillColor(nsColor.withAlphaComponent(0.3).cgColor)
        context.fillEllipse(in: rect)
      }
      if annotation.fillMode == .stroke || annotation.fillMode == .both {
        context.setStrokeColor(nsColor.cgColor)
        context.setLineWidth(strokeW)
        context.strokeEllipse(in: rect)
      }

    case .text:
      let scaledFontSize = annotation.fontSize * sf
      let nsStr = annotation.textContent as NSString
      let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: scaledFontSize, weight: .medium),
        .foregroundColor: nsColor,
      ]
      // Draw in the default CG coordinate system (bottom-left origin).
      // points[0] already has Y flipped to CG coords. Offset downward by
      // text height so the top of the text aligns with the annotation position.
      let textSize = nsStr.size(withAttributes: attrs)
      let drawPoint = CGPoint(x: points[0].x, y: points[0].y - textSize.height)
      nsStr.draw(at: drawPoint, withAttributes: attrs)

    case .stepCounter:
      guard !points.isEmpty else { break }
      let center = points[0]
      let radius = max(strokeW * 4, 14 * sf)
      let circleRect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
      )
      // Fill circle
      context.setFillColor(nsColor.cgColor)
      context.fillEllipse(in: circleRect)
      // Contrasting number text
      let deviceColor = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
      let luminance = 0.299 * deviceColor.redComponent + 0.587 * deviceColor.greenComponent + 0.114 * deviceColor.blueComponent
      let textColor: NSColor = luminance > 0.5 ? .black : .white
      let fontSize = radius * 1.1
      let numberStr = "\(annotation.stepNumber)" as NSString
      let textAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: textColor,
      ]
      let textSize = numberStr.size(withAttributes: textAttrs)
      // Draw in the default CG coordinate system (bottom-left origin).
      // center (points[0]) is already in CG coords. Position text so it
      // is vertically and horizontally centered on the circle.
      numberStr.draw(
        at: CGPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2),
        withAttributes: textAttrs
      )

    default:
      break
    }

    context.restoreGState()
  }

  private func exportPNG() {
    guard let (_, data) = flattenImage(), let pngData = data else { return }

    let timestamp = {
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
      return f.string(from: Date())
    }()

    let hostWindow = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
      styleMask: [.titled],
      backing: .buffered,
      defer: false
    )
    hostWindow.isReleasedWhenClosed = false
    hostWindow.center()
    hostWindow.alphaValue = 0
    hostWindow.orderFront(nil)

    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.png]
    savePanel.nameFieldStringValue = "Screenshot \(timestamp).png"
    savePanel.canCreateDirectories = true

    savePanel.beginSheetModal(for: hostWindow) { response in
      defer { hostWindow.close() }
      guard response == .OK, let url = savePanel.url else { return }
      try? pngData.write(to: url)
      showingExportConfirmation = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        showingExportConfirmation = false
      }
    }
  }
}

// MARK: - Window Drag Area

/// An NSViewRepresentable that allows dragging the window from a specific region.
/// Used on the header bar so the window can be repositioned without conflicting
/// with canvas drawing gestures.
private struct WindowDragArea: NSViewRepresentable {
  func makeNSView(context: Context) -> _DragAreaView {
    _DragAreaView()
  }

  func updateNSView(_ nsView: _DragAreaView, context: Context) {}
}

private class _DragAreaView: NSView {
  override var mouseDownCanMoveWindow: Bool { true }

  override func mouseDown(with event: NSEvent) {
    window?.performDrag(with: event)
  }
}

// MARK: - Scroll Wheel Pan

/// Captures scroll-wheel events via a local event monitor without blocking mouse clicks/drags.
struct ScrollWheelPanView: NSViewRepresentable {
  let onScroll: (_ dx: CGFloat, _ dy: CGFloat) -> Void

  func makeNSView(context: Context) -> _ScrollWheelCaptureView {
    let view = _ScrollWheelCaptureView()
    view.onScroll = onScroll
    return view
  }

  func updateNSView(_ nsView: _ScrollWheelCaptureView, context: Context) {
    nsView.onScroll = onScroll
  }
}

class _ScrollWheelCaptureView: NSView {
  var onScroll: ((_ dx: CGFloat, _ dy: CGFloat) -> Void)?
  private var monitor: Any?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil && monitor == nil {
      monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
        guard let self = self else { return event }
        let loc = self.convert(event.locationInWindow, from: nil)
        if self.bounds.contains(loc) {
          self.onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
        }
        return event
      }
    }
  }

  override func removeFromSuperview() {
    if let monitor = monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
    super.removeFromSuperview()
  }

  override func viewDidMoveToSuperview() {
    super.viewDidMoveToSuperview()
    if superview == nil, let monitor = monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
  }

  // Transparent to all mouse hit testing — clicks/drags pass through
  override func hitTest(_ point: NSPoint) -> NSView? {
    return nil
  }
}

// MARK: - Shared Editor Components

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
          .foregroundStyle(isActive ? Brand.white : .primary.opacity(0.7))
        Text(label)
          .font(.system(size: 9))
          .foregroundStyle(isActive ? Brand.white : .primary.opacity(0.5))
      }
      .frame(width: 50, height: 44)
      .background(isActive ? Brand.black : Color.primary.opacity(0.05))
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
            path.addLine(to: CGPoint(
              x: cropRect.minX + cropRect.width / 3, y: cropRect.maxY))
            path.move(to: CGPoint(
              x: cropRect.minX + cropRect.width * 2 / 3, y: cropRect.minY))
            path.addLine(to: CGPoint(
              x: cropRect.minX + cropRect.width * 2 / 3, y: cropRect.maxY))
            // Horizontal lines
            path.move(to: CGPoint(
              x: cropRect.minX, y: cropRect.minY + cropRect.height / 3))
            path.addLine(to: CGPoint(
              x: cropRect.maxX, y: cropRect.minY + cropRect.height / 3))
            path.move(to: CGPoint(
              x: cropRect.minX, y: cropRect.minY + cropRect.height * 2 / 3))
            path.addLine(to: CGPoint(
              x: cropRect.maxX, y: cropRect.minY + cropRect.height * 2 / 3))
          }
          .stroke(Color.primary.opacity(0.4), lineWidth: 1)
        }

        // Corner handles
        ForEach(
          Array(
            [
              CGPoint(x: cropRect.minX, y: cropRect.minY),
              CGPoint(x: cropRect.maxX, y: cropRect.minY),
              CGPoint(x: cropRect.minX, y: cropRect.maxY),
              CGPoint(x: cropRect.maxX, y: cropRect.maxY),
            ].enumerated()), id: \.offset
        ) { _, corner in
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
            .foregroundStyle(.primary)
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
            .foregroundStyle(.primary.opacity(0.6))
          Text("Drag to select crop area")
            .font(.system(size: 13))
            .foregroundStyle(.primary.opacity(0.6))
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
