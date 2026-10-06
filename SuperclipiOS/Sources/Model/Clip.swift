//
//  Clip.swift
//  Superclip for iPhone
//
//  Platform-neutral data model. IDs and timestamps are shaped for sync with
//  the Mac app: a clip keeps its UUID everywhere, "last used" moves it to the
//  top, and pinboards reference clips by ID.
//

import SwiftUI

enum ClipKind: String, Codable, CaseIterable, Identifiable {
    case text, link, image, color, code

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .color: return "Color"
        case .code: return "Code"
        }
    }

    var plural: String {
        switch self {
        case .text: return "Text"
        case .link: return "Links"
        case .image: return "Images"
        case .color: return "Colors"
        case .code: return "Code"
        }
    }

    var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .color: return "paintpalette"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// The one place colour is spent: a thin rule that says what a clip is.
    /// Same assignments as the Mac app's cards.
    var accent: Color {
        switch self {
        case .text: return Color(light: 0xE8590C, dark: 0xFF922B)
        case .link: return Color(light: 0x1C6FD6, dark: 0x5AA9FF)
        case .image: return Color(light: 0xD6336C, dark: 0xFF6B9D)
        case .color: return Color(light: 0x0A0A0A, dark: 0xF5F5F3)
        case .code: return Color(light: 0x7B3FC4, dark: 0xB98CF2)
        }
    }
}

struct Clip: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var content: String
    /// Page title for links.
    var title: String?
    /// File name of the stored image, for image clips.
    var imageFile: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var createdAt = Date()
    var lastUsedAt = Date()
    /// When the content was last edited; decides which edit wins in sync.
    var modifiedAt: Date?
    /// App the clip was copied from, when known ("Safari").
    var sourceApp: String?
    /// Device it was copied on ("Omar's MacBook Pro", "iPhone").
    var device: String

    var isFromThisDevice: Bool { device == Clip.thisDevice }

    static let thisDevice = "iPhone"

    /// Text shown on a card: the clip without surrounding blank lines.
    var displayText: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var host: String? {
        guard kind == .link, let url = URL(string: content) else { return nil }
        return url.host?.replacingOccurrences(of: "www.", with: "")
    }

    /// Short figure for the metadata line.
    var measure: String {
        switch kind {
        case .image:
            if let w = imageWidth, let h = imageHeight { return "\(w) \u{00D7} \(h)" }
            return "Image"
        case .link:
            return host ?? "Link"
        case .color:
            return content.uppercased()
        default:
            let count = content.count
            return "\(count) \(count == 1 ? "char" : "chars")"
        }
    }
}

struct Pinboard: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var tint: PinTint
    var clipIDs: [UUID] = []
    var modifiedAt: Date?
}

enum PinTint: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, blue, purple, pink, cyan

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: return Color(light: 0xE03131, dark: 0xFF6B6B)
        case .orange: return Color(light: 0xE8590C, dark: 0xFF922B)
        case .yellow: return Color(light: 0xE0A800, dark: 0xFFD43B)
        case .green: return Color(light: 0x2F9E44, dark: 0x51CF66)
        case .blue: return Color(light: 0x1C6FD6, dark: 0x5AA9FF)
        case .purple: return Color(light: 0x7B3FC4, dark: 0xB98CF2)
        case .pink: return Color(light: 0xD6336C, dark: 0xFF6B9D)
        case .cyan: return Color(light: 0x0C8599, dark: 0x3BC9DB)
        }
    }
}

struct Snippet: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var trigger: String
    var content: String
    /// Whether the Mac expands it while typing. The iPhone only carries it along.
    var isEnabled: Bool?
    var modifiedAt: Date?
}

// MARK: - Classifying pasted text

enum ClipClassifier {
    /// Decide what a piece of copied text is.
    static func kind(of text: String) -> ClipKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if rgb(from: trimmed) != nil { return .color }
        if !trimmed.contains(where: \.isWhitespace), let url = URL(string: trimmed),
            let scheme = url.scheme, ["http", "https"].contains(scheme), url.host != nil
        {
            return .link
        }
        if looksLikeCode(trimmed) { return .code }
        return .text
    }

    /// The colour a clip represents when the whole clip is one colour value.
    static func rgb(from text: String) -> (r: Double, g: Double, b: Double)? {
        var token = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.hasSuffix(";") { token.removeLast() }
        guard token.count <= 40 else { return nil }

        if token.hasPrefix("#") {
            var hex = String(token.dropFirst())
            guard [3, 6, 8].contains(hex.count), hex.allSatisfy(\.isHexDigit) else { return nil }
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            guard let value = UInt64(hex.prefix(6), radix: 16) else { return nil }
            return (
                Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255
            )
        }

        let lower = token.lowercased()
        if lower.hasPrefix("rgb"), lower.hasSuffix(")") {
            let numbers = lower.split(whereSeparator: { !$0.isNumber && $0 != "." }).compactMap { Double($0) }
            guard numbers.count >= 3, numbers.prefix(3).allSatisfy({ $0 <= 255 }) else { return nil }
            return (numbers[0] / 255, numbers[1] / 255, numbers[2] / 255)
        }
        return nil
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2 else { return false }
        var score = 0
        if text.contains("{") && text.contains("}") { score += 2 }
        if text.contains(";") { score += 2 }
        if text.contains("->") || text.contains("=>") { score += 2 }
        if lines.filter({ $0.hasPrefix("  ") || $0.hasPrefix("\t") }).count > lines.count / 3 { score += 2 }
        guard score > 0 else { return false }
        let keywords = ["func ", "function ", "def ", "class ", "import ", "return ", "const ", "let ", "var "]
        score += min(keywords.filter { text.contains($0) }.count * 2, 6)
        return score >= 4
    }
}
