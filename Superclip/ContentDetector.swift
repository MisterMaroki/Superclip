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

        // Detection runs on the main thread at copy time. Scanning a bounded
        // prefix keeps a multi-megabyte clip from stalling the app; a tag that
        // only applies past this point isn't worth the freeze.
        let sample = trimmed.count > maxScanLength ? String(trimmed.prefix(maxScanLength)) : trimmed

        var tags = Set<ContentTag>()

        if containsColor(sample)   { tags.insert(.color) }
        if containsEmail(sample)   { tags.insert(.email) }
        if containsPhone(sample)   { tags.insert(.phone) }
        if isJSON(trimmed)         { tags.insert(.json) }
        if looksLikeCode(sample)   { tags.insert(.code) }
        if containsAddress(sample) { tags.insert(.address) }

        return tags
    }

    private static let maxScanLength = 20_000

    // MARK: - Color Detection

    /// Hex: #RGB, #RRGGBB (word-boundary, not part of longer hex strings).
    /// The lookbehind rejects "abc#123" and HTML entities such as "&#123;".
    private static let hexColorRegex = try! NSRegularExpression(
        pattern: #"(?<![\w&])#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})\b"#
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
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        for match in hexColorRegex.matches(in: text, range: range) {
            let digits = ns.substring(with: match.range(at: 1))
            // "#123" inside a sentence is far more often an issue or ticket
            // number than a colour. All-digit shorthand only counts when it is
            // the entire clip.
            let isAllDigitShorthand = digits.count == 3 && digits.allSatisfy(\.isNumber)
            if !isAllDigitShorthand || match.range.length == ns.length { return true }
        }
        if rgbRegex.firstMatch(in: text, range: range) != nil { return true }
        if hslRegex.firstMatch(in: text, range: range) != nil { return true }
        return false
    }

    // MARK: - Single Color Value

    /// A colour in 0...1 sRGB components.
    struct RGB: Equatable {
        let r: Double
        let g: Double
        let b: Double

        /// Whether dark text reads better than light text on this colour.
        var prefersDarkText: Bool {
            0.299 * r + 0.587 * g + 0.114 * b > 0.6
        }
    }

    private static let singleHexRegex = try! NSRegularExpression(
        pattern: #"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#
    )

    /// rgb()/rgba() with comma or space separators and an optional alpha.
    private static let singleRGBRegex = try! NSRegularExpression(
        pattern: #"^rgba?\(\s*(\d{1,3})\s*[,\s]\s*(\d{1,3})\s*[,\s]\s*(\d{1,3})\s*(?:[,/]\s*[\d.]+%?\s*)?\)$"#,
        options: [.caseInsensitive]
    )

    private static let singleHSLRegex = try! NSRegularExpression(
        pattern: #"^hsla?\(\s*(\d{1,3})(?:deg)?\s*[,\s]\s*(\d{1,3})%?\s*[,\s]\s*(\d{1,3})%?\s*(?:[,/]\s*[\d.]+%?\s*)?\)$"#,
        options: [.caseInsensitive]
    )

    private final class RGBBox {
        let value: RGB?
        init(_ value: RGB?) { self.value = value }
    }

    private static let singleColorCache: NSCache<NSString, RGBBox> = {
        let cache = NSCache<NSString, RGBBox>()
        cache.countLimit = 500
        return cache
    }()

    /// The colour a clip represents when the whole clip is exactly one colour
    /// value (e.g. "#FF5733", "rgb(20, 20, 24)", "hsl(210, 50%, 40%)"), otherwise nil.
    /// Text that merely mentions a colour, such as a stylesheet, returns nil.
    static func singleColor(in text: String) -> RGB? {
        // Longest sensible single value is well under this; skip everything else cheaply.
        guard text.utf16.count <= 48 else { return nil }
        let key = text as NSString
        if let cached = singleColorCache.object(forKey: key) { return cached.value }
        let value = parseSingleColor(text)
        singleColorCache.setObject(RGBBox(value), forKey: key)
        return value
    }

    private static func parseSingleColor(_ text: String) -> RGB? {
        var token = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.hasSuffix(";") { token.removeLast() }
        let ns = token as NSString
        let range = NSRange(location: 0, length: ns.length)

        if let match = singleHexRegex.firstMatch(in: token, range: range) {
            var hex = ns.substring(with: match.range(at: 1))
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            // 8 digits = RRGGBBAA; the colour is the first six
            guard let value = UInt64(hex.prefix(6), radix: 16) else { return nil }
            return RGB(
                r: Double((value >> 16) & 0xFF) / 255,
                g: Double((value >> 8) & 0xFF) / 255,
                b: Double(value & 0xFF) / 255)
        }

        func ints(_ match: NSTextCheckingResult) -> [Double] {
            (1...3).compactMap { Double(ns.substring(with: match.range(at: $0))) }
        }

        if let match = singleRGBRegex.firstMatch(in: token, range: range) {
            let v = ints(match)
            guard v.count == 3, v.allSatisfy({ $0 <= 255 }) else { return nil }
            return RGB(r: v[0] / 255, g: v[1] / 255, b: v[2] / 255)
        }

        if let match = singleHSLRegex.firstMatch(in: token, range: range) {
            let v = ints(match)
            guard v.count == 3, v[0] <= 360, v[1] <= 100, v[2] <= 100 else { return nil }
            return hslToRGB(h: v[0], s: v[1] / 100, l: v[2] / 100)
        }

        return nil
    }

    private static func hslToRGB(h: Double, s: Double, l: Double) -> RGB {
        guard s > 0 else { return RGB(r: l, g: l, b: l) }
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r, g, b): (Double, Double, Double)
        switch h.truncatingRemainder(dividingBy: 360) {
        case 0..<60: (r, g, b) = (c, x, 0)
        case 60..<120: (r, g, b) = (x, c, 0)
        case 120..<180: (r, g, b) = (0, c, x)
        case 180..<240: (r, g, b) = (0, x, c)
        case 240..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return RGB(r: r + m, g: g + m, b: b + m)
    }

    // MARK: - Email Detection

    /// Bounded and left-anchored: the open-ended form rescanned a long
    /// unbroken token (base64, a JWT) from every offset and froze the app for
    /// seconds on a 20 KB clip.
    private static let emailRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9._%+\-])[A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{1,253}\.[A-Za-z]{2,}"#
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

    /// Matches URLs so we can strip them before phone detection.
    private static let urlRegex = try! NSRegularExpression(
        pattern: #"https?://\S+"#
    )

    private static func containsPhone(_ text: String) -> Bool {
        // Strip URLs first — long numeric paths (e.g. Discord IDs) cause false positives.
        let stripped = urlRegex.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: ""
        )
        let range = NSRange(stripped.startIndex..., in: stripped)
        let matches = phoneRegex.matches(in: stripped, range: range)

        for match in matches {
            guard var matchRange = Range(match.range, in: stripped) else { continue }
            // The pattern can swallow the space after the number. Drop it, or
            // the identifier check below sees the next word's first letter as
            // touching the match and rejects every number mid-sentence.
            while matchRange.upperBound > matchRange.lowerBound,
                  stripped[stripped.index(before: matchRange.upperBound)].isWhitespace {
                matchRange = matchRange.lowerBound..<stripped.index(before: matchRange.upperBound)
            }
            let matched = String(stripped[matchRange])
            guard isPlausiblePhone(matched) else { continue }

            // Reject matches embedded in alphanumeric-hyphen tokens
            // (e.g. "claude-opus-4-5-20251101", "v2.3.1234567")
            if matchEmbeddedInIdentifier(in: stripped, matchRange: matchRange) {
                continue
            }

            return true
        }

        return false
    }

    private static let dateLikeRegex = try! NSRegularExpression(
        pattern: #"^(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})$"#
    )
    private static let ipv4Regex = try! NSRegularExpression(
        pattern: #"^\d{1,3}(?:\.\d{1,3}){3}$"#
    )
    private static let decimalRegex = try! NSRegularExpression(pattern: #"^\d+\.\d+$"#)

    /// Whether a candidate digit run reads as a phone number rather than a
    /// date, IP address, decimal, timestamp or ID.
    static func isPlausiblePhone(_ candidate: String) -> Bool {
        let token = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitCount = token.filter(\.isNumber).count
        guard digitCount >= 7, digitCount <= 15 else { return false }

        let range = NSRange(location: 0, length: (token as NSString).length)
        if dateLikeRegex.firstMatch(in: token, range: range) != nil { return false }
        if ipv4Regex.firstMatch(in: token, range: range) != nil { return false }
        if decimalRegex.firstMatch(in: token, range: range) != nil { return false }

        // A bare run of digits is far more often a timestamp, order number or
        // ID than a phone number. Without a leading + it needs phone-style
        // separators to count.
        let hasSeparator = token.contains(where: { " -./()".contains($0) })
        return token.hasPrefix("+") || hasSeparator
    }

    /// Walk outward from match looking for letters connected via alphanumerics/hyphens/dots.
    /// If found, the match is part of an identifier (version string, model ID, etc.), not a phone number.
    private static func matchEmbeddedInIdentifier(in text: String, matchRange: Range<String.Index>) -> Bool {
        // Walk backwards
        var idx = matchRange.lowerBound
        while idx > text.startIndex {
            let prev = text.index(before: idx)
            let c = text[prev]
            if c.isLetter { return true }
            if c.isNumber || c == "-" || c == "." { idx = prev; continue }
            break
        }
        // Walk forwards
        idx = matchRange.upperBound
        while idx < text.endIndex {
            let c = text[idx]
            if c.isLetter { return true }
            if c.isNumber || c == "-" || c == "." { idx = text.index(after: idx); continue }
            break
        }
        return false
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
        if text.contains(";") { score += 2 }
        if text.contains("->") || text.contains("=>") { score += 2 }

        // Indentation pattern (lines starting with spaces/tabs)
        let indented = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
        if indented.count > lines.count / 3 { score += 2 }

        // Words like "if", "for", "let", "try" and "case" are ordinary English.
        // Without at least one structural signal a paragraph is not code.
        guard score > 0 else { return false }

        if text.contains("(") && text.contains(")") { score += 1 }
        if text.contains("//") || text.contains("/*") { score += 1 }

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

    /// Simple heuristic: a house number, one to five capitalised words, then a
    /// street suffix (St, Ave, Blvd, ...).
    ///
    /// Every part is bounded. The earlier `\d{1,5}\s+[\w\s]+` form backtracked
    /// quadratically: copying a column of 1,000 numbers from a spreadsheet
    /// froze the app for seconds. Requiring capitalised words also stops
    /// "5 people found a way" from being tagged as an address.
    private static let addressRegex = try! NSRegularExpression(
        pattern: #"(?<![\w])\d{1,5}[ \t]+(?:[A-Z0-9][\w.'\-]{0,30}[ \t]+){1,5}(?:Street|St|Avenue|Ave|Boulevard|Blvd|Drive|Dr|Road|Rd|Lane|Ln|Court|Ct|Way|Place|Pl|Highway|Hwy|Circle|Cir)\b"#
    )

    private static func containsAddress(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return addressRegex.firstMatch(in: text, range: range) != nil
    }
}
