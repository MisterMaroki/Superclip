//
//  AnnotationCanvasView.swift
//  Superclip
//

import SwiftUI

struct AnnotationCanvasView: View {
  @ObservedObject var state: AnnotationState
  let imageFrame: CGRect

  /// Pre-blurred copy of the full image for live blur preview.
  var blurPreviewNSImage: NSImage?

  /// Callback when a text annotation needs placement
  var onTextPlacement: ((CGPoint) -> Void)?

  // MARK: - Coordinate conversion

  private func toView(_ normalizedPoint: CGPoint) -> CGPoint {
    CGPoint(
      x: imageFrame.origin.x + normalizedPoint.x * imageFrame.width,
      y: imageFrame.origin.y + normalizedPoint.y * imageFrame.height
    )
  }

  private func toNormalized(_ viewPoint: CGPoint) -> CGPoint {
    guard imageFrame.width > 0, imageFrame.height > 0 else { return .zero }
    return CGPoint(
      x: (viewPoint.x - imageFrame.origin.x) / imageFrame.width,
      y: (viewPoint.y - imageFrame.origin.y) / imageFrame.height
    )
  }

  private func strokeWidthInView(_ annotation: Annotation) -> CGFloat {
    annotation.strokeWidth * (imageFrame.width / 500)
  }

  // MARK: - Body

  var body: some View {
    Canvas { context, size in
      // Resolve blur preview image once for all blur annotations
      let resolvedBlur: GraphicsContext.ResolvedImage? = blurPreviewNSImage.map {
        context.resolve(Image(nsImage: $0))
      }

      // Render committed annotations
      for annotation in state.annotations {
        render(
          annotation: annotation, in: &context, size: size,
          isSelected: annotation.id == state.selectedAnnotationId,
          resolvedBlur: resolvedBlur
        )
      }
      // Render in-progress annotation
      if let current = state.currentAnnotation {
        render(
          annotation: current, in: &context, size: size,
          isSelected: false, resolvedBlur: resolvedBlur
        )
      }
    }
    .contentShape(Rectangle())
    .gesture(dragGesture)
    .simultaneousGesture(tapGesture)
  }

  // MARK: - Gestures

  private var tapGesture: some Gesture {
    SpatialTapGesture()
      .onEnded { value in
        let loc = value.location
        if state.selectedTool == .text {
          let normalized = toNormalized(loc)
          state.textPlacementPoint = normalized
          state.isEditingText = true
          onTextPlacement?(normalized)
        } else if state.selectedTool == .stepCounter {
          let normalized = toNormalized(loc)
          let annotation = Annotation(
            tool: .stepCounter,
            color: state.selectedColor,
            strokeWidth: state.strokeWidth,
            points: [normalized],
            stepNumber: state.nextStepNumber
          )
          state.commitAnnotation(annotation)
        } else if state.selectedTool == .select {
          // Hit test annotations (reverse order for top-most)
          var found = false
          for annotation in state.annotations.reversed() {
            if hitTest(annotation: annotation, at: loc) {
              state.selectedAnnotationId = annotation.id
              found = true
              break
            }
          }
          if !found {
            state.selectedAnnotationId = nil
          }
        }
      }
  }

  /// Track whether we decided to drag-move on the initial onChanged.
  @State private var isDraggingAnnotation = false
  @State private var isResizingAnnotation = false

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 2)
      .onChanged { value in
        let startNorm = toNormalized(value.startLocation)
        let currentNorm = toNormalized(value.location)

        // First onChanged: decide resize vs move vs draw
        if state.resizingAnnotationId == nil
          && state.draggingAnnotationId == nil
          && state.currentAnnotation == nil
        {
          // Priority 1: Check resize handles on selected annotation
          if let (annotationId, handle) = hitTestResizeHandle(at: value.startLocation) {
            state.startResizing(annotationId, handle: handle, from: startNorm)
            isResizingAnnotation = true
            state.updateResize(to: currentNorm)
            return
          }

          // Priority 2: Hit-test existing annotations for drag-to-move
          for annotation in state.annotations.reversed() {
            if hitTest(annotation: annotation, at: value.startLocation) {
              state.startDragging(annotation.id, from: startNorm)
              isDraggingAnnotation = true
              state.updateDrag(to: currentNorm)
              return
            }
          }

          // Priority 3: Draw new annotation
          isDraggingAnnotation = false
          isResizingAnnotation = false

          guard state.selectedTool != .select && state.selectedTool != .text
            && state.selectedTool != .crop && state.selectedTool != .stepCounter
          else { return }

          var annotation = Annotation(
            tool: state.selectedTool,
            color: state.selectedColor,
            strokeWidth: state.strokeWidth,
            opacity: state.selectedTool == .highlighter ? 0.4 : 1.0,
            fillMode: state.fillMode,
            points: [startNorm],
            fontSize: state.fontSize,
            blurRadius: state.blurRadius,
            blurStyle: state.blurStyle
          )
          if state.selectedTool == .pencil || state.selectedTool == .highlighter {
            annotation.points.append(currentNorm)
          } else {
            annotation.points = [startNorm, currentNorm]
          }
          state.currentAnnotation = annotation
          return
        }

        // Subsequent onChanged: continue the active operation
        if state.resizingAnnotationId != nil {
          state.updateResize(to: currentNorm)
        } else if state.draggingAnnotationId != nil {
          state.updateDrag(to: currentNorm)
        } else if state.currentAnnotation != nil {
          if state.selectedTool == .pencil || state.selectedTool == .highlighter {
            state.currentAnnotation?.points.append(currentNorm)
          } else {
            if state.currentAnnotation!.points.count >= 2 {
              state.currentAnnotation?.points[1] = currentNorm
            } else {
              state.currentAnnotation?.points.append(currentNorm)
            }
          }
        }
      }
      .onEnded { _ in
        if state.resizingAnnotationId != nil {
          state.endResize()
          isResizingAnnotation = false
        } else if state.draggingAnnotationId != nil {
          state.endDrag()
          isDraggingAnnotation = false
        } else if let annotation = state.currentAnnotation,
          annotation.points.count >= 2
        {
          state.commitAnnotation(annotation)
        } else {
          state.currentAnnotation = nil
        }
      }
  }

  // MARK: - Text Bounds

  /// Compute the bounding rect for a text annotation in view coordinates,
  /// using the same scaled font as `renderText`.
  private func textBoundsInView(_ annotation: Annotation) -> CGRect {
    guard !annotation.points.isEmpty else { return .zero }
    let vp = toView(annotation.points[0])
    let scaledFontSize = annotation.fontSize * (imageFrame.width / 500)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: scaledFontSize, weight: .medium)
    ]
    let textSize = (annotation.textContent as NSString).size(withAttributes: attrs)
    return CGRect(
      x: vp.x,
      y: vp.y,
      width: max(textSize.width, 30),
      height: max(textSize.height, 20)
    )
  }

  // MARK: - Resize Handles

  private let handleHitRadius: CGFloat = 8

  /// Returns (handle, viewPosition) pairs for the given annotation.
  private func resizeHandles(for annotation: Annotation) -> [(ResizeHandle, CGPoint)] {
    switch annotation.tool {
    case .rectangle, .ellipse, .blur:
      guard annotation.points.count >= 2 else { return [] }
      let p0 = toView(annotation.points[0])
      let p1 = toView(annotation.points[1])
      let minX = min(p0.x, p1.x), maxX = max(p0.x, p1.x)
      let minY = min(p0.y, p1.y), maxY = max(p0.y, p1.y)

      var handles: [(ResizeHandle, CGPoint)] = [
        (.topLeft, CGPoint(x: minX, y: minY)),
        (.topRight, CGPoint(x: maxX, y: minY)),
        (.bottomLeft, CGPoint(x: minX, y: maxY)),
        (.bottomRight, CGPoint(x: maxX, y: maxY)),
      ]
      // Only show edge midpoints when the shape is large enough
      if (maxX - minX) > 30 && (maxY - minY) > 30 {
        handles += [
          (.topCenter, CGPoint(x: (minX + maxX) / 2, y: minY)),
          (.bottomCenter, CGPoint(x: (minX + maxX) / 2, y: maxY)),
          (.leftCenter, CGPoint(x: minX, y: (minY + maxY) / 2)),
          (.rightCenter, CGPoint(x: maxX, y: (minY + maxY) / 2)),
        ]
      }
      return handles

    case .line, .arrow:
      guard annotation.points.count >= 2 else { return [] }
      return [
        (.startPoint, toView(annotation.points[0])),
        (.endPoint, toView(annotation.points[1])),
      ]

    case .pencil, .highlighter:
      guard annotation.points.count >= 2 else { return [] }
      let viewPts = annotation.points.map { toView($0) }
      let xs = viewPts.map(\.x)
      let ys = viewPts.map(\.y)
      let minX = xs.min()!, maxX = xs.max()!
      let minY = ys.min()!, maxY = ys.max()!
      return [
        (.topLeft, CGPoint(x: minX, y: minY)),
        (.topRight, CGPoint(x: maxX, y: minY)),
        (.bottomLeft, CGPoint(x: minX, y: maxY)),
        (.bottomRight, CGPoint(x: maxX, y: maxY)),
      ]

    case .text:
      guard !annotation.points.isEmpty else { return [] }
      let bounds = textBoundsInView(annotation)
      return [(.textSize, CGPoint(x: bounds.maxX, y: bounds.maxY))]

    case .stepCounter:
      guard !annotation.points.isEmpty else { return [] }
      let center = toView(annotation.points[0])
      let sw = strokeWidthInView(annotation)
      let radius = max(sw * 4, 14)
      return [(.stepRadius, CGPoint(x: center.x + radius, y: center.y))]

    default:
      return []
    }
  }

  /// Hit-test resize handles on the currently selected annotation.
  private func hitTestResizeHandle(at point: CGPoint) -> (UUID, ResizeHandle)? {
    guard let selectedId = state.selectedAnnotationId,
          let annotation = state.annotations.first(where: { $0.id == selectedId })
    else { return nil }

    for (handle, handlePos) in resizeHandles(for: annotation) {
      if hypot(point.x - handlePos.x, point.y - handlePos.y) < handleHitRadius {
        return (selectedId, handle)
      }
    }
    return nil
  }

  // MARK: - Hit Testing

  private func hitTest(annotation: Annotation, at point: CGPoint) -> Bool {
    let threshold: CGFloat = 10

    switch annotation.tool {
    case .pencil, .highlighter:
      guard annotation.points.count >= 2 else { return false }
      for p in annotation.points {
        let vp = toView(p)
        if hypot(vp.x - point.x, vp.y - point.y) < threshold {
          return true
        }
      }
      return false
    case .line, .arrow:
      guard annotation.points.count >= 2 else { return false }
      let p0 = toView(annotation.points[0])
      let p1 = toView(annotation.points[1])
      // Check distance to line segment
      return distanceToSegment(point: point, a: p0, b: p1) < threshold
    case .stepCounter:
      guard !annotation.points.isEmpty else { return false }
      let vp = toView(annotation.points[0])
      let radius = max(strokeWidthInView(annotation) * 4, 14)
      return hypot(vp.x - point.x, vp.y - point.y) < radius
    case .rectangle, .ellipse, .blur:
      guard annotation.points.count >= 2 else { return false }
      let p0 = toView(annotation.points[0])
      let p1 = toView(annotation.points[1])
      let rect = CGRect(
        x: min(p0.x, p1.x) - threshold,
        y: min(p0.y, p1.y) - threshold,
        width: abs(p1.x - p0.x) + threshold * 2,
        height: abs(p1.y - p0.y) + threshold * 2
      )
      return rect.contains(point)
    case .text:
      guard !annotation.points.isEmpty else { return false }
      let textRect = textBoundsInView(annotation).insetBy(dx: -threshold, dy: -threshold)
      return textRect.contains(point)
    default:
      return false
    }
  }

  private func distanceToSegment(point: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let lenSq = dx * dx + dy * dy
    guard lenSq > 0 else { return hypot(point.x - a.x, point.y - a.y) }
    let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lenSq))
    let projX = a.x + t * dx
    let projY = a.y + t * dy
    return hypot(point.x - projX, point.y - projY)
  }

  // MARK: - Rendering

  private func render(
    annotation: Annotation,
    in context: inout GraphicsContext,
    size: CGSize,
    isSelected: Bool,
    resolvedBlur: GraphicsContext.ResolvedImage?
  ) {
    guard !annotation.points.isEmpty else { return }
    let viewPoints = annotation.points.map { toView($0) }
    let sw = strokeWidthInView(annotation)

    var ctx = context
    ctx.opacity = annotation.opacity

    switch annotation.tool {
    case .pencil:
      renderStroke(viewPoints, color: annotation.color, width: sw, in: &ctx)
    case .highlighter:
      renderStroke(viewPoints, color: annotation.color, width: sw * 3, in: &ctx)
    case .line:
      if viewPoints.count >= 2 {
        renderLine(from: viewPoints[0], to: viewPoints[1], color: annotation.color, width: sw, in: &ctx)
      }
    case .arrow:
      if viewPoints.count >= 2 {
        renderArrow(from: viewPoints[0], to: viewPoints[1], color: annotation.color, width: sw, in: &ctx)
      }
    case .rectangle:
      if viewPoints.count >= 2 {
        renderRect(from: viewPoints[0], to: viewPoints[1], annotation: annotation, width: sw, in: &ctx)
      }
    case .ellipse:
      if viewPoints.count >= 2 {
        renderEllipse(from: viewPoints[0], to: viewPoints[1], annotation: annotation, width: sw, in: &ctx)
      }
    case .text:
      renderText(annotation: annotation, at: viewPoints[0], in: &ctx)
    case .stepCounter:
      renderStepCounter(annotation: annotation, at: viewPoints[0], width: sw, in: &ctx)
    case .blur:
      if viewPoints.count >= 2 {
        renderBlurRegion(
          from: viewPoints[0], to: viewPoints[1],
          resolvedBlur: resolvedBlur, in: &context
        )
      }
    default:
      break
    }

    // Draw selection indicator
    if isSelected {
      let bounds: CGRect
      if annotation.tool == .pencil || annotation.tool == .highlighter {
        guard viewPoints.count >= 2 else { return }
        let xs = viewPoints.map(\.x)
        let ys = viewPoints.map(\.y)
        bounds = CGRect(
          x: (xs.min() ?? 0) - 4,
          y: (ys.min() ?? 0) - 4,
          width: ((xs.max() ?? 0) - (xs.min() ?? 0)) + 8,
          height: ((ys.max() ?? 0) - (ys.min() ?? 0)) + 8
        )
      } else if annotation.tool == .stepCounter {
        let p = viewPoints[0]
        let radius = max(sw * 4, 14)
        bounds = CGRect(x: p.x - radius - 2, y: p.y - radius - 2, width: (radius + 2) * 2, height: (radius + 2) * 2)
      } else if annotation.tool == .text {
        bounds = textBoundsInView(annotation).insetBy(dx: -4, dy: -4)
      } else if viewPoints.count >= 2 {
        let p0 = viewPoints[0]
        let p1 = viewPoints[1]
        bounds = CGRect(
          x: min(p0.x, p1.x) - 4,
          y: min(p0.y, p1.y) - 4,
          width: abs(p1.x - p0.x) + 8,
          height: abs(p1.y - p0.y) + 8
        )
      } else {
        return
      }
      let selPath = Path(roundedRect: bounds, cornerRadius: 2)
      context.stroke(
        selPath,
        with: .color(.blue),
        style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
      )

      // Draw resize handles
      let handleRadius: CGFloat = 5
      for (_, handlePos) in resizeHandles(for: annotation) {
        let handleRect = CGRect(
          x: handlePos.x - handleRadius,
          y: handlePos.y - handleRadius,
          width: handleRadius * 2,
          height: handleRadius * 2
        )
        let handlePath = Path(ellipseIn: handleRect)
        context.fill(handlePath, with: .color(Brand.white))
        context.stroke(handlePath, with: .color(.blue), style: StrokeStyle(lineWidth: 1.5))
      }
    }
  }

  private func renderStroke(
    _ points: [CGPoint],
    color: Color,
    width: CGFloat,
    in context: inout GraphicsContext
  ) {
    guard points.count >= 2 else { return }
    var path = Path()
    path.move(to: points[0])
    for i in 1..<points.count {
      path.addLine(to: points[i])
    }
    context.stroke(
      path,
      with: .color(color),
      style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    )
  }

  private func renderLine(
    from start: CGPoint,
    to end: CGPoint,
    color: Color,
    width: CGFloat,
    in context: inout GraphicsContext
  ) {
    var path = Path()
    path.move(to: start)
    path.addLine(to: end)
    context.stroke(
      path,
      with: .color(color),
      style: StrokeStyle(lineWidth: width, lineCap: .round)
    )
  }

  private func renderArrow(
    from start: CGPoint,
    to end: CGPoint,
    color: Color,
    width: CGFloat,
    in context: inout GraphicsContext
  ) {
    var shaft = Path()
    shaft.move(to: start)
    shaft.addLine(to: end)
    context.stroke(
      shaft,
      with: .color(color),
      style: StrokeStyle(lineWidth: width, lineCap: .round)
    )

    let angle = atan2(end.y - start.y, end.x - start.x)
    let headLength = max(width * 4, 12)
    let headAngle: CGFloat = .pi / 6

    let p1 = CGPoint(
      x: end.x - headLength * cos(angle - headAngle),
      y: end.y - headLength * sin(angle - headAngle)
    )
    let p2 = CGPoint(
      x: end.x - headLength * cos(angle + headAngle),
      y: end.y - headLength * sin(angle + headAngle)
    )

    var head = Path()
    head.move(to: p1)
    head.addLine(to: end)
    head.addLine(to: p2)
    context.stroke(
      head,
      with: .color(color),
      style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    )
  }

  private func renderRect(
    from p0: CGPoint,
    to p1: CGPoint,
    annotation: Annotation,
    width: CGFloat,
    in context: inout GraphicsContext
  ) {
    let rect = CGRect(
      x: min(p0.x, p1.x),
      y: min(p0.y, p1.y),
      width: abs(p1.x - p0.x),
      height: abs(p1.y - p0.y)
    )
    let path = Path(rect)

    if annotation.fillMode == .fill || annotation.fillMode == .both {
      context.fill(path, with: .color(annotation.color.opacity(0.3)))
    }
    if annotation.fillMode == .stroke || annotation.fillMode == .both {
      context.stroke(path, with: .color(annotation.color), style: StrokeStyle(lineWidth: width))
    }
  }

  private func renderEllipse(
    from p0: CGPoint,
    to p1: CGPoint,
    annotation: Annotation,
    width: CGFloat,
    in context: inout GraphicsContext
  ) {
    let rect = CGRect(
      x: min(p0.x, p1.x),
      y: min(p0.y, p1.y),
      width: abs(p1.x - p0.x),
      height: abs(p1.y - p0.y)
    )
    let path = Path(ellipseIn: rect)

    if annotation.fillMode == .fill || annotation.fillMode == .both {
      context.fill(path, with: .color(annotation.color.opacity(0.3)))
    }
    if annotation.fillMode == .stroke || annotation.fillMode == .both {
      context.stroke(path, with: .color(annotation.color), style: StrokeStyle(lineWidth: width))
    }
  }

  private func renderText(
    annotation: Annotation,
    at point: CGPoint,
    in context: inout GraphicsContext
  ) {
    guard !annotation.textContent.isEmpty else { return }
    let scaledFontSize = annotation.fontSize * (imageFrame.width / 500)
    let text = Text(annotation.textContent)
      .font(.system(size: scaledFontSize, weight: .medium))
      .foregroundColor(annotation.color)
    context.draw(text, at: point, anchor: .topLeading)
  }

  private func renderStepCounter(
    annotation: Annotation,
    at point: CGPoint,
    width: CGFloat,
    in context: inout GraphicsContext
  ) {
    let radius = max(width * 4, 14)
    let circleRect = CGRect(
      x: point.x - radius,
      y: point.y - radius,
      width: radius * 2,
      height: radius * 2
    )
    let circlePath = Path(ellipseIn: circleRect)
    context.fill(circlePath, with: .color(annotation.color))

    let textColor = contrastingTextColor(for: annotation.color)
    let fontSize = radius * 1.1
    let numberText = Text("\(annotation.stepNumber)")
      .font(.system(size: fontSize, weight: .bold, design: .rounded))
      .foregroundColor(textColor)
    context.draw(numberText, at: point, anchor: .center)
  }

  private func contrastingTextColor(for color: Color) -> Color {
    let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
    let r = nsColor.redComponent
    let g = nsColor.greenComponent
    let b = nsColor.blueComponent
    // BT.601 luminance
    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
    return luminance > 0.5 ? .black : .white
  }

  private func renderBlurRegion(
    from p0: CGPoint,
    to p1: CGPoint,
    resolvedBlur: GraphicsContext.ResolvedImage?,
    in context: inout GraphicsContext
  ) {
    let rect = CGRect(
      x: min(p0.x, p1.x),
      y: min(p0.y, p1.y),
      width: abs(p1.x - p0.x),
      height: abs(p1.y - p0.y)
    )

    if let blur = resolvedBlur {
      // Clip to the blur region and draw the precomputed blurred image
      var clipped = context
      clipped.clip(to: Path(rect))
      clipped.draw(blur, in: imageFrame)
    } else {
      // Fallback: hatched preview if no precomputed image
      let path = Path(rect)
      context.fill(path, with: .color(.gray.opacity(0.3)))
    }

    // Dashed border to indicate the blur region
    context.stroke(
      Path(rect),
      with: .color(Brand.white.opacity(0.5)),
      style: StrokeStyle(lineWidth: 1, dash: [4, 3])
    )
  }
}
