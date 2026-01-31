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

// MARK: - Detected Color Model

struct DetectedColor: Identifiable {
  let id = UUID()
  let raw: String  // original text matched (e.g. "#FF5733", "rgb(100, 200, 50)")
  let r: Int
  let g: Int
  let b: Int
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

  // MARK: Multi-Color Detection

  /// Detect all color values in the text, returning a deduplicated array of `DetectedColor`.
  static func detectAllColors(in text: String) -> [DetectedColor] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    var results: [DetectedColor] = []
    var seen = Set<String>()  // deduplicate by "r,g,b"

    // Hex colors
    for match in allMatches(pattern: hexColorPattern, in: trimmed) {
      let hex = match.hasPrefix("#") ? match : "#\(match)"
      if let (r, g, b) = parseHexColor(hex) {
        let key = "\(r),\(g),\(b)"
        if !seen.contains(key) {
          seen.insert(key)
          results.append(DetectedColor(raw: hex, r: r, g: g, b: b))
        }
      }
    }

    // RGB colors
    for match in allMatches(pattern: rgbColorPattern, in: trimmed) {
      let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
      if nums.count >= 3, nums[0] <= 255, nums[1] <= 255, nums[2] <= 255 {
        let key = "\(nums[0]),\(nums[1]),\(nums[2])"
        if !seen.contains(key) {
          seen.insert(key)
          results.append(DetectedColor(raw: match, r: nums[0], g: nums[1], b: nums[2]))
        }
      }
    }

    // HSL colors
    for match in allMatches(pattern: hslColorPattern, in: trimmed) {
      let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
      if nums.count >= 3 {
        let (r, g, b) = hslToRGB(h: Double(nums[0]), s: Double(nums[1]) / 100.0, l: Double(nums[2]) / 100.0)
        let key = "\(r),\(g),\(b)"
        if !seen.contains(key) {
          seen.insert(key)
          results.append(DetectedColor(raw: match, r: r, g: g, b: b))
        }
      }
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

  private static func allMatches(pattern: String, in text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, range: range)
    return matches.compactMap { match in
      let groupRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
      guard let swiftRange = Range(groupRange, in: text) else { return nil }
      return String(text[swiftRange])
    }
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

// MARK: - Color Spectrum View

struct ColorSpectrumView: View {
  @Binding var hue: Double        // 0...360
  @Binding var saturation: Double // 0...1
  var brightness: Double          // 0...1

  var body: some View {
    GeometryReader { geo in
      let size = geo.size
      ZStack {
        // Hue gradient (horizontal)
        LinearGradient(
          gradient: Gradient(colors: stride(from: 0.0, through: 360.0, by: 30.0).map { h in
            Color(hue: h / 360.0, saturation: 1.0, brightness: brightness)
          }),
          startPoint: .leading,
          endPoint: .trailing
        )

        // Saturation overlay: white at top fading to transparent at bottom
        LinearGradient(
          gradient: Gradient(colors: [
            Color.white.opacity(1.0),
            Color.white.opacity(0.0),
          ]),
          startPoint: .top,
          endPoint: .bottom
        )

        // Crosshair indicator
        Circle()
          .fill(Color(hue: hue / 360.0, saturation: saturation, brightness: brightness))
          .frame(width: 14, height: 14)
          .overlay(
            Circle()
              .stroke(Color.white, lineWidth: 2)
          )
          .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
          .position(
            x: (hue / 360.0) * size.width,
            y: (1.0 - saturation) * size.height
          )
      }
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let newHue = min(max(value.location.x / size.width, 0), 1) * 360.0
            let newSat = 1.0 - min(max(value.location.y / size.height, 0), 1)
            hue = newHue
            saturation = newSat
          }
      )
    }
    .frame(height: 80)
    .cornerRadius(6)
  }
}

// MARK: - Color Channel Slider

struct ColorChannelSlider: View {
  let label: String
  @Binding var value: Double
  var range: ClosedRange<Double>
  var color: Color

  var body: some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 12, alignment: .trailing)

      GeometryReader { geo in
        let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        ZStack(alignment: .leading) {
          // Track background
          Capsule()
            .fill(Color.primary.opacity(0.1))
            .frame(height: 6)

          // Filled portion
          Capsule()
            .fill(color.opacity(0.7))
            .frame(width: max(6, CGFloat(fraction) * geo.size.width), height: 6)

          // Thumb
          Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            .offset(x: max(0, CGFloat(fraction) * (geo.size.width - 12)))
        }
        .frame(height: 12)
        .position(x: geo.size.width / 2, y: geo.size.height / 2)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { drag in
              let fraction = min(max(drag.location.x / geo.size.width, 0), 1)
              value = range.lowerBound + Double(fraction) * (range.upperBound - range.lowerBound)
            }
        )
      }
      .frame(height: 18)

      Text("\(Int(value))")
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.secondary)
        .frame(width: 28, alignment: .trailing)
    }
  }
}

// MARK: - Inline Color Editor

struct InlineColorEditor: View {
  @Binding var hue: Double
  @Binding var saturation: Double
  @Binding var brightness: Double
  @Binding var red: Double
  @Binding var green: Double
  @Binding var blue: Double

  private var previewColor: Color {
    Color(
      nsColor: QuickActionAnalyzer.nsColor(
        r: Int(red),
        g: Int(green),
        b: Int(blue)
      )
    )
  }

  private var hexText: String {
    QuickActionAnalyzer.hexString(r: Int(red), g: Int(green), b: Int(blue))
  }

  var body: some View {
    VStack(spacing: 8) {
      // Row 1: Spectrum + swatch preview
      HStack(spacing: 10) {
        ColorSpectrumView(
          hue: $hue,
          saturation: $saturation,
          brightness: brightness
        )

        VStack(spacing: 4) {
          RoundedRectangle(cornerRadius: 6)
            .fill(previewColor)
            .frame(width: 48, height: 48)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
          Text(hexText)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
        }
      }

      // Brightness slider
      ColorChannelSlider(
        label: "B",
        value: $brightness,
        range: 0...100,
        color: .gray
      )

      // RGB sliders
      ColorChannelSlider(
        label: "R",
        value: $red,
        range: 0...255,
        color: .red
      )
      ColorChannelSlider(
        label: "G",
        value: $green,
        range: 0...255,
        color: .green
      )
      ColorChannelSlider(
        label: "B",
        value: $blue,
        range: 0...255,
        color: .blue
      )
    }
    .padding(10)
    .background(Color.primary.opacity(0.04))
    .cornerRadius(8)
  }
}

// MARK: - Color Editor State

class ColorEditorState: ObservableObject, Identifiable {
  let id = UUID()
  let original: DetectedColor

  @Published var adjustedR: Double
  @Published var adjustedG: Double
  @Published var adjustedB: Double
  @Published var adjustedHue: Double = 0
  @Published var adjustedSaturation: Double = 1.0
  @Published var adjustedBrightness: Double = 100
  var isUpdating = false

  init(color: DetectedColor) {
    self.original = color
    self.adjustedR = Double(color.r)
    self.adjustedG = Double(color.g)
    self.adjustedB = Double(color.b)
    syncHSBFromRGB()
  }

  func syncHSBFromRGB() {
    guard !isUpdating else { return }
    isUpdating = true
    let nsColor = NSColor(
      red: CGFloat(adjustedR) / 255.0,
      green: CGFloat(adjustedG) / 255.0,
      blue: CGFloat(adjustedB) / 255.0,
      alpha: 1.0
    )
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    adjustedHue = Double(h) * 360.0
    adjustedSaturation = Double(s)
    adjustedBrightness = Double(b) * 100.0
    isUpdating = false
  }

  func syncRGBFromHSB() {
    guard !isUpdating else { return }
    isUpdating = true
    let nsColor = NSColor(
      hue: CGFloat(adjustedHue / 360.0),
      saturation: CGFloat(adjustedSaturation),
      brightness: CGFloat(adjustedBrightness / 100.0),
      alpha: 1.0
    )
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    adjustedR = Double(r) * 255.0
    adjustedG = Double(g) * 255.0
    adjustedB = Double(b) * 255.0
    isUpdating = false
  }
}

// MARK: - Quick Actions Bar (for PreviewView)

struct QuickActionsBar: View {
  let item: ClipboardItem
  @ObservedObject private var feedback = QuickActionFeedback.shared

  // Multi-color state
  @State private var colorStates: [ColorEditorState] = []
  @State private var selectedColorIndex: Int = 0
  @State private var isColorEditorExpanded: Bool = false
  @State private var colorsInitialized: Bool = false

  private var actions: [QuickAction] {
    QuickActionsProvider.actions(for: item)
  }

  private var detectedTypes: [DetectedContentType] {
    QuickActionsProvider.detectedTypes(for: item)
  }

  private var hasColors: Bool {
    !colorStates.isEmpty
  }

  private var selectedState: ColorEditorState? {
    guard selectedColorIndex >= 0, selectedColorIndex < colorStates.count else { return nil }
    return colorStates[selectedColorIndex]
  }

  /// Non-color actions to display alongside dynamic color copy buttons.
  private var nonColorActions: [QuickAction] {
    guard hasColors else { return actions }
    let colorActionTitles: Set<String> = [
      "Copy as RGB", "Copy as HSL", "Copy as Hex",
    ]
    return actions.filter { !colorActionTitles.contains($0.title) }
  }

  private func colorCopyButton(title: String, icon: String, value: String) -> some View {
    Button {
      let pb = NSPasteboard.general
      pb.clearContents()
      pb.setString(value, forType: .string)
      QuickActionFeedback.shared.show("Copied!")
    } label: {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 10))
        Text(title)
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

  private func initializeColors() {
    guard !colorsInitialized else { return }
    colorsInitialized = true
    let detected = QuickActionAnalyzer.detectAllColors(in: item.content)
    colorStates = detected.map { ColorEditorState(color: $0) }
    selectedColorIndex = 0
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

        // Color chip strip (if colors detected)
        if hasColors {
          HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 6) {
                ForEach(Array(colorStates.enumerated()), id: \.element.id) { index, state in
                  ColorChipView(
                    state: state,
                    isSelected: index == selectedColorIndex
                  )
                  .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                      selectedColorIndex = index
                    }
                  }
                }
              }
            }

            Button {
              withAnimation(.easeInOut(duration: 0.25)) {
                isColorEditorExpanded.toggle()
              }
            } label: {
              Image(systemName: isColorEditorExpanded ? "chevron.up" : "slider.horizontal.3")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
          }

          // Expanded color editor for selected color
          if isColorEditorExpanded, let state = selectedState {
            ColorEditorView(state: state)
              .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }

        // Action buttons in a flowing layout
        FlowLayout(spacing: 6) {
          // Dynamic color copy buttons (use selected color's adjusted values)
          if let state = selectedState {
            colorCopyButton(
              title: "Copy Hex",
              icon: "number",
              value: QuickActionAnalyzer.hexString(
                r: Int(state.adjustedR), g: Int(state.adjustedG), b: Int(state.adjustedB)
              )
            )
            colorCopyButton(
              title: "Copy RGB",
              icon: "paintpalette",
              value: QuickActionAnalyzer.rgbString(
                r: Int(state.adjustedR), g: Int(state.adjustedG), b: Int(state.adjustedB)
              )
            )
            colorCopyButton(
              title: "Copy HSL",
              icon: "paintpalette.fill",
              value: QuickActionAnalyzer.hslString(
                r: Int(state.adjustedR), g: Int(state.adjustedG), b: Int(state.adjustedB)
              )
            )
          }

          // Non-color actions (or all actions if no color detected)
          ForEach(hasColors ? nonColorActions : actions) { qa in
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
      .onAppear { initializeColors() }
    }
  }
}

// MARK: - Color Chip View

struct ColorChipView: View {
  @ObservedObject var state: ColorEditorState
  let isSelected: Bool

  private var chipColor: Color {
    Color(nsColor: QuickActionAnalyzer.nsColor(
      r: Int(state.adjustedR), g: Int(state.adjustedG), b: Int(state.adjustedB)
    ))
  }

  var body: some View {
    HStack(spacing: 5) {
      RoundedRectangle(cornerRadius: 3)
        .fill(chipColor)
        .frame(width: 20, height: 20)
        .overlay(
          RoundedRectangle(cornerRadius: 3)
            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
        )
      Text(state.original.raw)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.primary.opacity(0.8))
        .lineLimit(1)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
    )
    .contentShape(Rectangle())
  }
}

// MARK: - Color Editor View (wraps InlineColorEditor with bindings to ColorEditorState)

struct ColorEditorView: View {
  @ObservedObject var state: ColorEditorState

  var body: some View {
    InlineColorEditor(
      hue: $state.adjustedHue,
      saturation: $state.adjustedSaturation,
      brightness: $state.adjustedBrightness,
      red: $state.adjustedR,
      green: $state.adjustedG,
      blue: $state.adjustedB
    )
    .onChange(of: state.adjustedR) { _ in state.syncHSBFromRGB() }
    .onChange(of: state.adjustedG) { _ in state.syncHSBFromRGB() }
    .onChange(of: state.adjustedB) { _ in state.syncHSBFromRGB() }
    .onChange(of: state.adjustedHue) { _ in state.syncRGBFromHSB() }
    .onChange(of: state.adjustedSaturation) { _ in state.syncRGBFromHSB() }
    .onChange(of: state.adjustedBrightness) { _ in state.syncRGBFromHSB() }
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
