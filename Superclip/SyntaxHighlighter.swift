//
//  SyntaxHighlighter.swift
//  Superclip
//

import AppKit

enum SyntaxHighlighter {

    // MARK: - Public

    /// Cheap code-detection check without paying for colorization.
    static func isCode(_ text: String) -> Bool {
        looksLikeCode(text)
    }

    /// Memoized colorized output — card/preview bodies call highlight() on every
    /// SwiftUI evaluation, so recomputing 70+ regex passes each time stalls the
    /// main thread on large clips.
    private static let cache: NSCache<NSString, NSAttributedString> = {
        let c = NSCache<NSString, NSAttributedString>()
        c.countLimit = 40
        return c
    }()

    /// Colorization is O(regexes × length); above this size fall back to plain text.
    private static let maxHighlightLength = 50_000

    /// Texts already judged not to be code. Without this the (linear but not
    /// free) code heuristic re-ran on every card render for every plain clip.
    private static let notCode: NSCache<NSString, NSNumber> = {
        let c = NSCache<NSString, NSNumber>()
        c.countLimit = 400
        return c
    }()

    /// Returns a highlighted attributed string if the text looks like code, otherwise nil.
    static func highlight(_ text: String) -> NSAttributedString? {
        let key = text as NSString
        // Cache first: both the positive and the negative answer
        if let cached = cache.object(forKey: key) { return cached }
        if notCode.object(forKey: key) != nil { return nil }

        guard text.utf16.count <= maxHighlightLength, looksLikeCode(text) else {
            notCode.setObject(1, forKey: key)
            return nil
        }
        let result = colorize(text)
        cache.setObject(result, forKey: key)
        return result
    }

    // MARK: - Code Detection

    private static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return false }

        var score = 0

        // Structural indicators
        if text.contains("{") && text.contains("}") { score += 2 }
        if text.contains("(") && text.contains(")") { score += 1 }
        if text.contains(";") { score += 2 }
        if text.contains("->") || text.contains("=>") { score += 2 }
        if text.contains("//") || text.contains("/*") || text.contains("#") { score += 1 }

        // Indentation pattern (lines starting with spaces/tabs)
        let indented = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
        if indented.count > lines.count / 3 { score += 2 }

        // Keyword presence
        let joined = text.lowercased()
        let codeKeywords = ["func ", "function ", "def ", "class ", "import ", "return ",
                            "const ", "let ", "var ", "if ", "else ", "for ", "while ",
                            "switch ", "case ", "struct ", "enum ", "interface ",
                            "public ", "private ", "async ", "await ", "try ", "catch "]
        let matchCount = codeKeywords.filter { joined.contains($0) }.count
        score += min(matchCount * 2, 6)

        return score >= 4
    }

    // MARK: - Colorization

    private static let keywords: Set<String> = [
        // Swift / general
        "func", "var", "let", "class", "struct", "enum", "protocol", "extension",
        "import", "return", "if", "else", "guard", "switch", "case", "default",
        "for", "while", "repeat", "break", "continue", "in", "do", "try", "catch",
        "throw", "throws", "async", "await", "public", "private", "internal", "open",
        "static", "override", "init", "deinit", "self", "super", "nil", "true", "false",
        "typealias", "where", "is", "as",
        // JavaScript / TypeScript
        "function", "const", "new", "this", "typeof", "instanceof", "void", "export",
        "from", "of", "delete", "yield", "interface", "type",
        // Python
        "def", "lambda", "with", "finally", "raise", "pass", "assert",
        "and", "or", "not", "None", "True", "False", "nonlocal", "global",
        "elif", "except",
        // Rust / Go / C
        "fn", "mut", "pub", "impl", "trait", "use", "mod", "crate",
        "int", "float", "double", "char", "bool", "string",
        "package", "fmt", "println", "printf",
    ]

    private static func colorize(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
        ])

        // The system accent colours are tuned for dark backgrounds; systemGreen
        // and systemOrange at 11pt are barely readable on a light card. Each
        // token colour therefore has its own light-mode value.
        func adaptive(light: UInt32, dark: UInt32) -> NSColor {
            func rgb(_ hex: UInt32) -> NSColor {
                NSColor(
                    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
            }
            return NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? rgb(dark) : rgb(light)
            }
        }
        let keywordColor = adaptive(light: 0x8E24AA, dark: 0xD9A0F5)
        let stringColor = adaptive(light: 0xC41A16, dark: 0xFF8A80)
        let numberColor = adaptive(light: 0xA84A00, dark: 0xFFB45E)
        let commentColor = adaptive(light: 0x2E7D32, dark: 0x86C98F)

        let nsText = text as NSString

        // Order matters: later passes paint over earlier ones. Keywords and
        // numbers go first so that strings, then comments, win where they
        // overlap. (Painted the other way round, "// return if ready" showed
        // "return" and "if" as keywords inside the comment.)

        // Highlight keywords (word-boundary match)
        for keyword in keywords {
            applyRegex("\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b",
                        to: result, in: nsText, color: keywordColor)
        }

        // Highlight numbers
        applyRegex("\\b\\d+(\\.\\d+)?\\b", to: result, in: nsText, color: numberColor)

        // Highlight strings (double-quoted and single-quoted, non-greedy)
        applyRegex("\"(?:[^\"\\\\]|\\\\.)*\"", to: result, in: nsText, color: stringColor)
        applyRegex("'(?:[^'\\\\]|\\\\.)*'", to: result, in: nsText, color: stringColor)

        // Highlight single-line comments. "#" only counts at the start of a
        // line or after whitespace and before a space or "!", so CSS colours
        // (#fff), "#if" and "#selector" are left alone.
        applyRegex("//[^\n]*", to: result, in: nsText, color: commentColor)
        applyRegex("(?m)(?:^|(?<=\\s))#[ !][^\n]*", to: result, in: nsText, color: commentColor)

        // Highlight multi-line comments /* ... */
        applyRegex("/\\*[\\s\\S]*?\\*/", to: result, in: nsText, color: commentColor)

        return result
    }

    private static func applyRegex(
        _ pattern: String,
        to attributedString: NSMutableAttributedString,
        in nsText: NSString,
        color: NSColor
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let fullRange = NSRange(location: 0, length: nsText.length)
        for match in regex.matches(in: nsText as String, options: [], range: fullRange) {
            attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
