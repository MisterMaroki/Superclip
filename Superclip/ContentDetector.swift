//
//  ContentDetector.swift
//  Superclip
//

import Foundation

// MARK: - Content Tag

/// Auto-detected sub-category tags for clipboard text content.
enum ContentTag: String, Codable, CaseIterable, Hashable {
    case color
    case email
    case phone
    case code
    case json
    case address
}

// MARK: - Content Detector

/// Static methods for detecting content types within clipboard text via regex/heuristics.
/// All detection is synchronous, fast, and offline — no external API calls.
enum ContentDetector {

    // MARK: - Public API

    /// Detect all applicable content tags for the given text.
    static func detect(text: String) -> Set<ContentTag> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var tags = Set<ContentTag>()

        if containsColor(trimmed)   { tags.insert(.color) }
        if containsEmail(trimmed)   { tags.insert(.email) }
        if containsPhone(trimmed)   { tags.insert(.phone) }
        if isJSON(trimmed)          { tags.insert(.json) }
        if looksLikeCode(trimmed)   { tags.insert(.code) }
        if containsAddress(trimmed) { tags.insert(.address) }

        return tags
    }

    // MARK: - Color Detection

    /// Hex: #RGB, #RRGGBB (word-boundary, not part of longer hex strings)
    private static let hexColorRegex = try! NSRegularExpression(
        pattern: #"#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})\b"#
    )

    /// rgb(r, g, b) or rgba(r, g, b, a)
    private static let rgbRegex = try! NSRegularExpression(
        pattern: #"rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}"#
    )

    /// hsl(h, s%, l%) or hsla(h, s%, l%, a)
    private static let hslRegex = try! NSRegularExpression(
        pattern: #"hsla?\(\s*\d{1,3}"#
    )

    private static func containsColor(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        if hexColorRegex.firstMatch(in: text, range: range) != nil { return true }
        if rgbRegex.firstMatch(in: text, range: range) != nil { return true }
        if hslRegex.firstMatch(in: text, range: range) != nil { return true }
        return false
    }

    // MARK: - Email Detection

    private static let emailRegex = try! NSRegularExpression(
        pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
    )

    private static func containsEmail(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return emailRegex.firstMatch(in: text, range: range) != nil
    }

    // MARK: - Phone Detection

    /// International phone number pattern. Requires at least 7 digits total.
    private static let phoneRegex = try! NSRegularExpression(
        pattern: #"[\+]?[(]?[0-9]{1,4}[)]?[-\s\./0-9]{7,15}"#
    )

    private static func containsPhone(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = phoneRegex.firstMatch(in: text, range: range) else { return false }
        // Extra validation: the matched string must contain at least 7 actual digits
        let matchRange = Range(match.range, in: text)!
        let matched = String(text[matchRange])
        let digitCount = matched.filter { $0.isNumber }.count
        return digitCount >= 7
    }

    // MARK: - JSON Detection

    private static func isJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return false }
        guard let data = trimmed.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    // MARK: - Code Detection (heuristic)

    private static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        // Need at least 3 lines to qualify as a code snippet
        guard lines.count >= 3 else { return false }

        var score = 0

        // Structural indicators
        if text.contains("{") && text.contains("}") { score += 2 }
        if text.contains("(") && text.contains(")") { score += 1 }
        if text.contains(";") { score += 2 }
        if text.contains("->") || text.contains("=>") { score += 2 }
        if text.contains("//") || text.contains("/*") { score += 1 }

        // Indentation pattern (lines starting with spaces/tabs)
        let indented = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
        if indented.count > lines.count / 3 { score += 2 }

        // Keyword presence
        let joined = text.lowercased()
        let codeKeywords = [
            "func ", "function ", "def ", "class ", "import ", "return ",
            "const ", "let ", "var ", "if ", "else ", "for ", "while ",
            "switch ", "case ", "struct ", "enum ", "interface ",
            "public ", "private ", "async ", "await ", "try ", "catch ",
        ]
        let matchCount = codeKeywords.filter { joined.contains($0) }.count
        score += min(matchCount * 2, 6)

        return score >= 4
    }

    // MARK: - Address Detection (basic)

    /// Simple heuristic: number followed by street-like words (St, Ave, Blvd, Dr, Rd, etc.)
    private static let addressRegex = try! NSRegularExpression(
        pattern: #"\d{1,5}\s+[\w\s]+\b(Street|St|Avenue|Ave|Boulevard|Blvd|Drive|Dr|Road|Rd|Lane|Ln|Court|Ct|Way|Place|Pl|Highway|Hwy|Circle|Cir)\b"#,
        options: .caseInsensitive
    )

    private static func containsAddress(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return addressRegex.firstMatch(in: text, range: range) != nil
    }
}
