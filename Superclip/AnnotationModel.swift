//
//  AnnotationModel.swift
//  Superclip
//

import Combine
import SwiftUI

// MARK: - Annotation Tool

enum AnnotationTool: String, CaseIterable, Identifiable {
  case select
  case pencil
  case line
  case arrow
  case rectangle
  case ellipse
  case text
  case stepCounter
  case highlighter
  case blur
  case crop

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .select: return "cursorarrow"
    case .pencil: return "pencil.tip"
    case .line: return "line.diagonal"
    case .arrow: return "arrow.up.right"
    case .rectangle: return "rectangle"
    case .ellipse: return "circle"
    case .text: return "textformat"
    case .stepCounter: return "number.circle.fill"
    case .highlighter: return "highlighter"
    case .blur: return "drop.halffull"
    case .crop: return "crop"
    }
  }

  var label: String {
    switch self {
    case .select: return "Select"
    case .pencil: return "Pencil"
    case .line: return "Line"
    case .arrow: return "Arrow"
    case .rectangle: return "Rectangle"
    case .ellipse: return "Ellipse"
    case .text: return "Text"
    case .stepCounter: return "Step"
    case .highlighter: return "Highlighter"
    case .blur: return "Blur"
    case .crop: return "Crop"
    }
  }
}

// MARK: - Fill Mode

enum FillMode: String {
  case stroke
  case fill
  case both
}

// MARK: - Blur Style

enum BlurStyle: String {
  case gaussian
  case pixelate
}

// MARK: - Annotation

struct Annotation: Identifiable, Equatable {
  let id: UUID
  let tool: AnnotationTool
  var color: Color
  var strokeWidth: CGFloat
  var opacity: Double
  var fillMode: FillMode
  /// Points in normalized coordinates (0...1 relative to image)
  var points: [CGPoint]
  var textContent: String
  var fontSize: CGFloat
  var blurRadius: CGFloat
  var blurStyle: BlurStyle
  var stepNumber: Int

  init(
    id: UUID = UUID(),
    tool: AnnotationTool,
    color: Color = .red,
    strokeWidth: CGFloat = 3,
    opacity: Double = 1.0,
    fillMode: FillMode = .stroke,
    points: [CGPoint] = [],
    textContent: String = "",
    fontSize: CGFloat = 16,
    blurRadius: CGFloat = 10,
    blurStyle: BlurStyle = .gaussian,
    stepNumber: Int = 0
  ) {
    self.id = id
    self.tool = tool
    self.color = color
    self.strokeWidth = strokeWidth
    self.opacity = opacity
    self.fillMode = fillMode
    self.points = points
    self.textContent = textContent
    self.fontSize = fontSize
    self.blurRadius = blurRadius
    self.blurStyle = blurStyle
    self.stepNumber = stepNumber
  }

  static func == (lhs: Annotation, rhs: Annotation) -> Bool {
    lhs.id == rhs.id
      && lhs.tool == rhs.tool
      && lhs.strokeWidth == rhs.strokeWidth
      && lhs.opacity == rhs.opacity
      && lhs.fillMode == rhs.fillMode
      && lhs.points == rhs.points
      && lhs.textContent == rhs.textContent
      && lhs.fontSize == rhs.fontSize
      && lhs.blurRadius == rhs.blurRadius
      && lhs.blurStyle == rhs.blurStyle
      && lhs.stepNumber == rhs.stepNumber
  }
}

// MARK: - Resize Handle

enum ResizeHandle: Equatable {
  // Corner handles (rect/ellipse/blur shapes, freeform bounding box)
  case topLeft, topRight, bottomLeft, bottomRight
  // Edge midpoint handles (rect/ellipse/blur shapes)
  case topCenter, bottomCenter, leftCenter, rightCenter
  // Endpoint handles (line/arrow)
  case startPoint, endPoint
  // Single-property handles
  case textSize       // text: adjusts fontSize
  case stepRadius     // stepCounter: adjusts strokeWidth
}

// MARK: - Annotation State

class AnnotationState: ObservableObject {
  @Published var annotations: [Annotation] = []
  @Published var currentAnnotation: Annotation?
  @Published var selectedTool: AnnotationTool = .pencil
  @Published var selectedColor: Color = .red
  @Published var strokeWidth: CGFloat = 3
  @Published var fillMode: FillMode = .stroke
  @Published var fontSize: CGFloat = 16
  @Published var blurStyle: BlurStyle = .gaussian
  @Published var blurRadius: CGFloat = 10
  @Published var selectedAnnotationId: UUID?

  /// Text annotation placement state
  @Published var textPlacementPoint: CGPoint?
  @Published var isEditingText: Bool = false

  /// Drag-to-move state
  @Published var draggingAnnotationId: UUID?
  private var dragStartPoints: [CGPoint]?
  private var dragStartNormalized: CGPoint?

  /// Resize state
  @Published var resizingAnnotationId: UUID?
  var activeResizeHandle: ResizeHandle?
  private var resizeStartPoints: [CGPoint]?
  private var resizeStartNormalized: CGPoint?
  private var resizeStartFontSize: CGFloat?
  private var resizeStartStrokeWidth: CGFloat?

  private var undoStack: [[Annotation]] = []
  private var redoStack: [[Annotation]] = []
  private let maxUndoLevels = 50

  var canUndo: Bool { !undoStack.isEmpty }
  var canRedo: Bool { !redoStack.isEmpty }

  var nextStepNumber: Int {
    let max = annotations.filter { $0.tool == .stepCounter }.map(\.stepNumber).max() ?? 0
    return max + 1
  }

  func pushUndoState() {
    undoStack.append(annotations)
    if undoStack.count > maxUndoLevels {
      undoStack.removeFirst()
    }
    redoStack.removeAll()
  }

  func undo() {
    guard let previous = undoStack.popLast() else { return }
    redoStack.append(annotations)
    annotations = previous
  }

  func redo() {
    guard let next = redoStack.popLast() else { return }
    undoStack.append(annotations)
    annotations = next
  }

  func commitAnnotation(_ annotation: Annotation) {
    pushUndoState()
    annotations.append(annotation)
    currentAnnotation = nil
  }

  func deleteSelected() {
    guard let selectedId = selectedAnnotationId else { return }
    pushUndoState()
    annotations.removeAll { $0.id == selectedId }
    selectedAnnotationId = nil
  }

  // MARK: - Drag-to-move

  func startDragging(_ annotationId: UUID, from normalizedPoint: CGPoint) {
    guard let index = annotations.firstIndex(where: { $0.id == annotationId }) else { return }
    draggingAnnotationId = annotationId
    dragStartPoints = annotations[index].points
    dragStartNormalized = normalizedPoint
    selectedAnnotationId = annotationId
  }

  func updateDrag(to normalizedPoint: CGPoint) {
    guard let dragId = draggingAnnotationId,
          let startPoints = dragStartPoints,
          let startNorm = dragStartNormalized,
          let index = annotations.firstIndex(where: { $0.id == dragId })
    else { return }

    let dx = normalizedPoint.x - startNorm.x
    let dy = normalizedPoint.y - startNorm.y

    annotations[index].points = startPoints.map { p in
      CGPoint(x: p.x + dx, y: p.y + dy)
    }
  }

  func endDrag() {
    guard let dragId = draggingAnnotationId,
          let startPoints = dragStartPoints,
          let index = annotations.firstIndex(where: { $0.id == dragId })
    else {
      draggingAnnotationId = nil
      dragStartPoints = nil
      dragStartNormalized = nil
      return
    }

    // Only push undo if points actually changed
    if annotations[index].points != startPoints {
      let movedPoints = annotations[index].points
      annotations[index].points = startPoints
      pushUndoState()
      annotations[index].points = movedPoints
    }

    draggingAnnotationId = nil
    dragStartPoints = nil
    dragStartNormalized = nil
  }

  // MARK: - Resize

  func startResizing(_ annotationId: UUID, handle: ResizeHandle, from normalizedPoint: CGPoint) {
    guard let index = annotations.firstIndex(where: { $0.id == annotationId }) else { return }
    resizingAnnotationId = annotationId
    activeResizeHandle = handle
    resizeStartPoints = annotations[index].points
    resizeStartNormalized = normalizedPoint
    resizeStartFontSize = annotations[index].fontSize
    resizeStartStrokeWidth = annotations[index].strokeWidth
    selectedAnnotationId = annotationId
  }

  func updateResize(to normalizedPoint: CGPoint) {
    guard let resizeId = resizingAnnotationId,
          let handle = activeResizeHandle,
          let startPoints = resizeStartPoints,
          let index = annotations.firstIndex(where: { $0.id == resizeId })
    else { return }

    let tool = annotations[index].tool

    switch tool {
    case .rectangle, .ellipse, .blur:
      guard startPoints.count >= 2 else { return }
      let oMinX = min(startPoints[0].x, startPoints[1].x)
      let oMaxX = max(startPoints[0].x, startPoints[1].x)
      let oMinY = min(startPoints[0].y, startPoints[1].y)
      let oMaxY = max(startPoints[0].y, startPoints[1].y)

      switch handle {
      case .topLeft:
        annotations[index].points = [normalizedPoint, CGPoint(x: oMaxX, y: oMaxY)]
      case .topRight:
        annotations[index].points = [CGPoint(x: oMinX, y: oMaxY), CGPoint(x: normalizedPoint.x, y: normalizedPoint.y)]
      case .bottomLeft:
        annotations[index].points = [CGPoint(x: normalizedPoint.x, y: normalizedPoint.y), CGPoint(x: oMaxX, y: oMinY)]
      case .bottomRight:
        annotations[index].points = [CGPoint(x: oMinX, y: oMinY), normalizedPoint]
      case .topCenter:
        annotations[index].points = [CGPoint(x: oMinX, y: normalizedPoint.y), CGPoint(x: oMaxX, y: oMaxY)]
      case .bottomCenter:
        annotations[index].points = [CGPoint(x: oMinX, y: oMinY), CGPoint(x: oMaxX, y: normalizedPoint.y)]
      case .leftCenter:
        annotations[index].points = [CGPoint(x: normalizedPoint.x, y: oMinY), CGPoint(x: oMaxX, y: oMaxY)]
      case .rightCenter:
        annotations[index].points = [CGPoint(x: oMinX, y: oMinY), CGPoint(x: normalizedPoint.x, y: oMaxY)]
      default: break
      }

    case .line, .arrow:
      guard startPoints.count >= 2 else { return }
      switch handle {
      case .startPoint:
        annotations[index].points[0] = normalizedPoint
      case .endPoint:
        annotations[index].points[1] = normalizedPoint
      default: break
      }

    case .pencil, .highlighter:
      guard startPoints.count >= 2 else { return }
      let xs = startPoints.map(\.x)
      let ys = startPoints.map(\.y)
      let oMinX = xs.min()!, oMaxX = xs.max()!
      let oMinY = ys.min()!, oMaxY = ys.max()!
      let oWidth = oMaxX - oMinX
      let oHeight = oMaxY - oMinY
      guard oWidth > 0.001, oHeight > 0.001 else { return }

      let anchor: CGPoint
      switch handle {
      case .topLeft:     anchor = CGPoint(x: oMaxX, y: oMaxY)
      case .topRight:    anchor = CGPoint(x: oMinX, y: oMaxY)
      case .bottomLeft:  anchor = CGPoint(x: oMaxX, y: oMinY)
      case .bottomRight: anchor = CGPoint(x: oMinX, y: oMinY)
      default: return
      }

      let newMinX = min(anchor.x, normalizedPoint.x)
      let newMaxX = max(anchor.x, normalizedPoint.x)
      let newMinY = min(anchor.y, normalizedPoint.y)
      let newMaxY = max(anchor.y, normalizedPoint.y)
      let newWidth = newMaxX - newMinX
      let newHeight = newMaxY - newMinY

      annotations[index].points = startPoints.map { p in
        let tx = (p.x - oMinX) / oWidth
        let ty = (p.y - oMinY) / oHeight
        return CGPoint(x: newMinX + tx * newWidth, y: newMinY + ty * newHeight)
      }

    case .text:
      guard handle == .textSize,
            let startFontSize = resizeStartFontSize,
            let startNorm = resizeStartNormalized
      else { return }
      let dx = normalizedPoint.x - startNorm.x
      let dy = normalizedPoint.y - startNorm.y
      let delta = (dx + dy) / 2
      let scaleFactor = 1.0 + delta * 4
      annotations[index].fontSize = max(8, min(200, startFontSize * scaleFactor))

    case .stepCounter:
      guard handle == .stepRadius,
            let startStrokeWidth = resizeStartStrokeWidth,
            let startNorm = resizeStartNormalized
      else { return }
      let dx = normalizedPoint.x - startNorm.x
      let scaleFactor = 1.0 + dx * 8
      annotations[index].strokeWidth = max(1, min(40, startStrokeWidth * scaleFactor))

    default:
      break
    }
  }

  func endResize() {
    guard let resizeId = resizingAnnotationId,
          let startPoints = resizeStartPoints,
          let index = annotations.firstIndex(where: { $0.id == resizeId })
    else {
      clearResizeState()
      return
    }

    let changed = annotations[index].points != startPoints
      || annotations[index].fontSize != (resizeStartFontSize ?? annotations[index].fontSize)
      || annotations[index].strokeWidth != (resizeStartStrokeWidth ?? annotations[index].strokeWidth)

    if changed {
      let current = annotations[index]
      annotations[index].points = startPoints
      if let sf = resizeStartFontSize { annotations[index].fontSize = sf }
      if let sw = resizeStartStrokeWidth { annotations[index].strokeWidth = sw }
      pushUndoState()
      annotations[index] = current
    }

    clearResizeState()
  }

  private func clearResizeState() {
    resizingAnnotationId = nil
    activeResizeHandle = nil
    resizeStartPoints = nil
    resizeStartNormalized = nil
    resizeStartFontSize = nil
    resizeStartStrokeWidth = nil
  }

  func reset() {
    if !annotations.isEmpty {
      pushUndoState()
    }
    annotations.removeAll()
    currentAnnotation = nil
    selectedAnnotationId = nil
    textPlacementPoint = nil
    isEditingText = false
    clearResizeState()
  }
}
