//
//  QuickActions.swift
//  Superclip
//

import AppKit
import Combine
import SwiftUI

// MARK: - Quick Action Model

struct QuickAction: Identifiable {
  let id = UUID()
  let title: String
  let icon: String  // SF Symbol name
  let action: (ClipboardItem) -> Void
}

// MARK: - Content Type Detection

enum DetectedContentType {
  case colorHex(hex: String, r: Int, g: Int, b: Int)
  case colorRGB(raw: String, r: Int, g: Int, b: Int)
  case colorHSL(raw: String, r: Int, g: Int, b: Int)
  case json(raw: String)
  case email(address: String)
  case phone(raw: String, digits: String)
  case code(raw: String)
  case filePath(path: String)
}

// MARK: - Content Detector

enum QuickActionAnalyzer {

  // MARK: Patterns

  private static let hexColorPattern = #"(?:^|\s)(#[0-9A-Fa-f]{6})\b"#
  private static let rgbColorPattern = #"rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}"#
  private static let hslColorPattern = #"hsla?\(\s*\d{1,3}\s*,\s*\d{1,3}%?\s*,\s*\d{1,3}%?"#
  private static let emailPattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
  private static let phonePattern =
    #"^[\+]?[(]?[0-9]{1,4}[)]?[-\s./0-9()]{6,18}$"#
  private static let filePathPattern = #"^[~/](?:[^\x00]+/)*[^\x00]+$"#

  // MARK: Detection

  /// Detect all matching content types for a clipboard item.
  /// Returns multiple matches when applicable (e.g. text that is both a email and contains a color).
  static func detect(_ item: ClipboardItem) -> [DetectedContentType] {
    // Only analyse text-based items
    guard item.type == .text else { return [] }

    let text = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return [] }

    var results: [DetectedContentType] = []

    // Color hex — look for pattern anywhere in text
    if let match = firstMatch(pattern: hexColorPattern, in: text) {
      let hex = match.hasPrefix("#") ? match : String(match.dropFirst())
      if let (r, g, b) = parseHexColor(hex) {
        results.append(.colorHex(hex: hex.hasPrefix("#") ? hex : "#\(hex)", r: r, g: g, b: b))
      }
    }

    // Color rgb/rgba — e.g. rgb(100, 200, 50)
    if let match = firstMatch(pattern: rgbColorPattern, in: text) {
      let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
      if nums.count >= 3, nums[0] <= 255, nums[1] <= 255, nums[2] <= 255 {
        results.append(.colorRGB(raw: match, r: nums[0], g: nums[1], b: nums[2]))
      }
    }

    // Color hsl/hsla — e.g. hsl(210, 80%, 50%)
    if let match = firstMatch(pattern: hslColorPattern, in: text) {
      let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
      if nums.count >= 3 {
        let (r, g, b) = hslToRGB(h: Double(nums[0]), s: Double(nums[1]) / 100.0, l: Double(nums[2]) / 100.0)
        results.append(.colorHSL(raw: match, r: r, g: g, b: b))
      }
    }

    // JSON — quick sniff: starts with { or [
    if (text.hasPrefix("{") || text.hasPrefix("[")) && isValidJSON(text) {
      results.append(.json(raw: text))
    }

    // Email
    if matches(pattern: emailPattern, in: text) {
      results.append(.email(address: text))
    }

    // Phone
    let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if matches(pattern: phonePattern, in: stripped) {
      let digits = stripped.filter { $0.isNumber || $0 == "+" }
      if digits.count >= 7 {
        results.append(.phone(raw: stripped, digits: digits))
      }
    }

    // File path (Unix-style)
    if matches(pattern: filePathPattern, in: text) && !text.contains("\n") {
      results.append(.filePath(path: text))
    }

    // Code detection (reuse SyntaxHighlighter's heuristic — multi-line + structure)
    if results.isEmpty, SyntaxHighlighter.highlight(text) != nil {
      results.append(.code(raw: text))
    }

    return results
  }

  // MARK: Color Conversions

  static func parseHexColor(_ hex: String) -> (r: Int, g: Int, b: Int)? {
    let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return nil }
    let r = Int((value >> 16) & 0xFF)
    let g = Int((value >> 8) & 0xFF)
    let b = Int(value & 0xFF)
    return (r, g, b)
  }

  static func rgbString(r: Int, g: Int, b: Int) -> String {
    "rgb(\(r), \(g), \(b))"
  }

  static func hslString(r: Int, g: Int, b: Int) -> String {
    let rf = Double(r) / 255.0
    let gf = Double(g) / 255.0
    let bf = Double(b) / 255.0

    let maxC = max(rf, gf, bf)
    let minC = min(rf, gf, bf)
    let delta = maxC - minC

    // Lightness
    let l = (maxC + minC) / 2.0

    guard delta > 0 else {
      return "hsl(0, 0%, \(Int(round(l * 100)))%)"
    }

    // Saturation
    let s = l < 0.5 ? delta / (maxC + minC) : delta / (2.0 - maxC - minC)

    // Hue
    var h: Double
    if maxC == rf {
      h = ((gf - bf) / delta).truncatingRemainder(dividingBy: 6)
    } else if maxC == gf {
      h = (bf - rf) / delta + 2
    } else {
      h = (rf - gf) / delta + 4
    }
    h *= 60
    if h < 0 { h += 360 }

    return "hsl(\(Int(round(h))), \(Int(round(s * 100)))%, \(Int(round(l * 100)))%)"
  }

  static func hexString(r: Int, g: Int, b: Int) -> String {
    String(format: "#%02X%02X%02X", r, g, b)
  }

  private static func hslToRGB(h: Double, s: Double, l: Double) -> (Int, Int, Int) {
    guard s > 0 else {
      let v = Int(round(l * 255))
      return (v, v, v)
    }
    let c = (1 - abs(2 * l - 1)) * s
    let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
    let m = l - c / 2
    let (r1, g1, b1): (Double, Double, Double)
    switch h {
    case 0..<60:   (r1, g1, b1) = (c, x, 0)
    case 60..<120:  (r1, g1, b1) = (x, c, 0)
    case 120..<180: (r1, g1, b1) = (0, c, x)
    case 180..<240: (r1, g1, b1) = (0, x, c)
    case 240..<300: (r1, g1, b1) = (x, 0, c)
    default:        (r1, g1, b1) = (c, 0, x)
    }
    return (Int(round((r1 + m) * 255)), Int(round((g1 + m) * 255)), Int(round((b1 + m) * 255)))
  }

  static func nsColor(r: Int, g: Int, b: Int) -> NSColor {
    NSColor(
      red: CGFloat(r) / 255.0,
      green: CGFloat(g) / 255.0,
      blue: CGFloat(b) / 255.0,
      alpha: 1.0
    )
  }

  // MARK: JSON Helpers

  static func prettyPrintJSON(_ raw: String) -> String? {
    guard let data = raw.data(using: .utf8),
      let obj = try? JSONSerialization.jsonObject(with: data),
      let pretty = try? JSONSerialization.data(
        withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
    else { return nil }
    return String(data: pretty, encoding: .utf8)
  }

  static func minifyJSON(_ raw: String) -> String? {
    guard let data = raw.data(using: .utf8),
      let obj = try? JSONSerialization.jsonObject(with: data),
      let compact = try? JSONSerialization.data(withJSONObject: obj, options: [])
    else { return nil }
    return String(data: compact, encoding: .utf8)
  }

  static func jsonAsEscapedString(_ raw: String) -> String? {
    guard let data = raw.data(using: .utf8),
      (try? JSONSerialization.jsonObject(with: data)) != nil
    else { return nil }
    // Escape the JSON as a string literal
    return
      raw
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\t", with: "\\t")
  }

  // MARK: Code Helpers

  static func stripIndentation(_ code: String) -> String {
    let lines = code.components(separatedBy: .newlines)
    // Find minimum leading whitespace (ignoring blank lines)
    let minIndent =
      lines
      .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
      .map { line -> Int in
        let stripped = line.drop(while: { $0 == " " || $0 == "\t" })
        return line.count - stripped.count
      }
      .min() ?? 0

    guard minIndent > 0 else { return code }

    return
      lines
      .map { line in
        if line.count >= minIndent {
          return String(line.dropFirst(minIndent))
        }
        return line
      }
      .joined(separator: "\n")
  }

  static func wrapInCodeBlock(_ code: String) -> String {
    "```\n\(code)\n```"
  }

  // MARK: Regex Helpers

  private static func matches(pattern: String, in text: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(text.startIndex..., in: text)
    return regex.firstMatch(in: text, range: range) != nil
  }

  private static func firstMatch(pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range) else { return nil }
    // Use capture group 1 if available, else full match
    let groupRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
    guard let swiftRange = Range(groupRange, in: text) else { return nil }
    return String(text[swiftRange])
  }

  private static func isValidJSON(_ text: String) -> Bool {
    guard let data = text.data(using: .utf8) else { return false }
    return (try? JSONSerialization.jsonObject(with: data)) != nil
  }
}

// MARK: - Quick Actions Provider

enum QuickActionsProvider {

  /// Clipboard helper: copy a string to the pasteboard.
  private static func copyToPasteboard(_ string: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(string, forType: .string)
  }

  /// Return the list of quick actions applicable to `item`.
  static func actions(for item: ClipboardItem) -> [QuickAction] {
    let detected = QuickActionAnalyzer.detect(item)
    guard !detected.isEmpty else { return [] }

    var actions: [QuickAction] = []

    for type in detected {
      switch type {

      // MARK: Color Hex

      case .colorHex(_, let r, let g, let b):
        actions.append(
          QuickAction(
            title: "Copy as RGB",
            icon: "paintpalette",
            action: { _ in
              copyToPasteboard(QuickActionAnalyzer.rgbString(r: r, g: g, b: b))
              QuickActionFeedback.shared.show("Copied!")
            }
          ))
        actions.append(
          QuickAction(
            title: "Copy as HSL",
            icon: "paintpalette.fill",
            action: { _ in
              copyToPasteboard(QuickActionAnalyzer.hslString(r: r, g: g, b: b))
              QuickActionFeedback.shared.show("Copied!")
            }
          ))

      // MARK: Color RGB

      case .colorRGB(_, let r, let g, let b):
        actions.append(
          QuickAction(
            title: "Copy as Hex",
            icon: "number",
            action: { _ in
              copyToPasteboard(QuickActionAnalyzer.hexString(r: r, g: g, b: b))
              QuickActionFeedback.shared.show("Copied!")
            }
          ))
        actions.append(
          QuickAction(
            title: "Copy as HSL",
            icon: "paintpalette.fill",
            action: { _ in
              copyToPasteboard(QuickActionAnalyzer.hslString(r: r, g: g, b: b))
              QuickActionFeedback.shared.show("Copied!")
            }
          ))

      // MARK: Color HSL

      case .colorHSL(_, let r, let g, let b):
        actions.append(
          QuickAction(
            title: "Copy as Hex",
            icon: "number",
            action: { _ in
              copyToPasteboard(QuickActionAnalyzer.hexString(r: r, g: g, b: b))
              QuickActionFeedback.shared.show("Copied!")
            }
          ))
        actions.append(
          QuickAction(
            title: "Copy as RGB",
            icon: "paintpalette",
            action: { _ in
              copyToPasteboard(QuickActionAnalyzer.rgbString(r: r, g: g, b: b))
              QuickActionFeedback.shared.show("Copied!")
            }
          ))

      // MARK: JSON

      case .json(let raw):
        if let pretty = QuickActionAnalyzer.prettyPrintJSON(raw) {
          actions.append(
            QuickAction(
              title: "Pretty Print",
              icon: "text.alignleft",
              action: { _ in
                copyToPasteboard(pretty)
                QuickActionFeedback.shared.show("Copied!")
              }
            ))
        }
        if let mini = QuickActionAnalyzer.minifyJSON(raw) {
          actions.append(
            QuickAction(
              title: "Minify",
              icon: "arrow.right.arrow.left",
              action: { _ in
                copyToPasteboard(mini)
                QuickActionFeedback.shared.show("Copied!")
              }
            ))
        }
        if let escaped = QuickActionAnalyzer.jsonAsEscapedString(raw) {
          actions.append(
            QuickAction(
              title: "Copy as String",
              icon: "doc.text",
              action: { _ in
                copyToPasteboard(escaped)
                QuickActionFeedback.shared.show("Copied!")
              }
            ))
        }

      // MARK: Email

      case .email(let address):
        actions.append(
          QuickAction(
            title: "Compose Email",
            icon: "envelope",
            action: { _ in
              if let mailto = URL(string: "mailto:\(address)") {
                NSWorkspace.shared.open(mailto)
              }
            }
          ))
        actions.append(
          QuickAction(
            title: "Copy Address",
            icon: "at",
            action: { _ in
              copyToPasteboard(address)
              QuickActionFeedback.shared.show("Copied!")
            }
          ))

      // MARK: Phone

      case .phone(_, let digits):
        actions.append(
          QuickAction(
            title: "Call via FaceTime",
            icon: "phone",
            action: { _ in
              if let ftURL = URL(string: "facetime:\(digits)") {
                NSWorkspace.shared.open(ftURL)
              }
            }
          ))
        actions.append(
          QuickAction(
            title: "Copy Digits Only",
            icon: "number",
            action: { _ in
              copyToPasteboard(digits)
              QuickActionFeedback.shared.show("Copied!")
            }
          ))

      // MARK: Code

      case .code(let raw):
        actions.append(
          QuickAction(
            title: "Copy Without Indentation",
            icon: "decrease.indent",
            action: { _ in
              copyToPasteboard(QuickActionAnalyzer.stripIndentation(raw))
              QuickActionFeedback.shared.show("Copied!")
            }
          ))
        actions.append(
          QuickAction(
            title: "Wrap in Code Block",
            icon: "chevron.left.forwardslash.chevron.right",
            action: { _ in
              copyToPasteboard(QuickActionAnalyzer.wrapInCodeBlock(raw))
              QuickActionFeedback.shared.show("Copied!")
            }
          ))

      // MARK: File Path

      case .filePath(let path):
        let expandedPath =
          path.hasPrefix("~")
          ? (path as NSString).expandingTildeInPath
          : path
        actions.append(
          QuickAction(
            title: "Open in Finder",
            icon: "folder",
            action: { _ in
              let url = URL(fileURLWithPath: expandedPath)
              NSWorkspace.shared.activateFileViewerSelecting([url])
            }
          ))
        let filename = (expandedPath as NSString).lastPathComponent
        actions.append(
          QuickAction(
            title: "Copy Filename Only",
            icon: "doc",
            action: { _ in
              copyToPasteboard(filename)
              QuickActionFeedback.shared.show("Copied!")
            }
          ))
        let parent = (expandedPath as NSString).deletingLastPathComponent
        actions.append(
          QuickAction(
            title: "Copy Parent Directory",
            icon: "folder.fill",
            action: { _ in
              copyToPasteboard(parent)
              QuickActionFeedback.shared.show("Copied!")
            }
          ))
      }
    }

    return actions
  }

  /// Extract detected content types for UI embellishments (e.g. color swatch).
  static func detectedTypes(for item: ClipboardItem) -> [DetectedContentType] {
    QuickActionAnalyzer.detect(item)
  }
}

// MARK: - Feedback Toast (observable)

class QuickActionFeedback: ObservableObject {
  static let shared = QuickActionFeedback()
  @Published var message: String?

  func show(_ text: String) {
    DispatchQueue.main.async {
      self.message = text
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        if self.message == text {
          self.message = nil
        }
      }
    }
  }
}

// MARK: - Quick Actions Bar (for PreviewView)

struct QuickActionsBar: View {
  let item: ClipboardItem
  @ObservedObject private var feedback = QuickActionFeedback.shared

  private var actions: [QuickAction] {
    QuickActionsProvider.actions(for: item)
  }

  private var detectedTypes: [DetectedContentType] {
    QuickActionsProvider.detectedTypes(for: item)
  }

  /// Extract color info from any color detection type.
  private var colorInfo: (r: Int, g: Int, b: Int)? {
    for t in detectedTypes {
      switch t {
      case .colorHex(_, let r, let g, let b),
           .colorRGB(_, let r, let g, let b),
           .colorHSL(_, let r, let g, let b):
        return (r, g, b)
      default:
        continue
      }
    }
    return nil
  }

  var body: some View {
    if !actions.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        // Section header
        HStack(spacing: 6) {
          Image(systemName: "bolt.fill")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
          Text("Quick Actions")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
          Spacer()

          // Feedback toast
          if let msg = feedback.message {
            Text(msg)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(.green)
              .transition(.opacity.combined(with: .scale))
          }
        }

        // Color swatch (if applicable)
        if let c = colorInfo {
          HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(nsColor: QuickActionAnalyzer.nsColor(r: c.r, g: c.g, b: c.b)))
              .frame(width: 28, height: 28)
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .stroke(Color.primary.opacity(0.2), lineWidth: 1)
              )
            Text(QuickActionAnalyzer.rgbString(r: c.r, g: c.g, b: c.b))
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.secondary)
          }
        }

        // Action buttons in a flowing layout
        FlowLayout(spacing: 6) {
          ForEach(actions) { qa in
            Button {
              qa.action(item)
            } label: {
              HStack(spacing: 4) {
                Image(systemName: qa.icon)
                  .font(.system(size: 10))
                Text(qa.title)
                  .font(.system(size: 11, weight: .medium))
              }
              .foregroundStyle(.primary.opacity(0.85))
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(Color.primary.opacity(0.08))
              .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(Color.primary.opacity(0.03))
      .animation(.easeInOut(duration: 0.2), value: feedback.message)
    }
  }
}

// MARK: - Simple Flow Layout

struct FlowLayout: Layout {
  var spacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let result = layout(in: proposal.width ?? .infinity, subviews: subviews)
    return result.size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let result = layout(in: bounds.width, subviews: subviews)
    for (index, position) in result.positions.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: .unspecified
      )
    }
  }

  private struct LayoutResult {
    var positions: [CGPoint]
    var size: CGSize
  }

  private func layout(in maxWidth: CGFloat, subviews: Subviews) -> LayoutResult {
    var positions: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var maxX: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > maxWidth && x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      rowHeight = max(rowHeight, size.height)
      x += size.width + spacing
      maxX = max(maxX, x)
    }

    return LayoutResult(
      positions: positions,
      size: CGSize(width: maxX, height: y + rowHeight)
    )
  }
}

// MARK: - Context Menu Quick Actions

struct QuickActionsContextMenu: View {
  let item: ClipboardItem

  private var actions: [QuickAction] {
    QuickActionsProvider.actions(for: item)
  }

  var body: some View {
    if !actions.isEmpty {
      Menu {
        ForEach(actions) { qa in
          Button {
            qa.action(item)
          } label: {
            Label(qa.title, systemImage: qa.icon)
          }
        }
      } label: {
        Label("Quick Actions", systemImage: "bolt.fill")
      }
    }
  }
}
