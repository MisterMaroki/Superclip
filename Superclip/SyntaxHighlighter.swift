//
//  SyntaxHighlighter.swift
//  Superclip
//

import AppKit

enum SyntaxHighlighter {

    // MARK: - Public

    /// Returns a highlighted attributed string if the text looks like code, otherwise nil.
    static func highlight(_ text: String) -> NSAttributedString? {
        guard looksLikeCode(text) else { return nil }
        return colorize(text)
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

        let keywordColor = NSColor.systemPurple
        let stringColor = NSColor.systemRed
        let numberColor = NSColor.systemOrange
        let commentColor = NSColor.systemGreen

        let nsText = text as NSString

        // Highlight single-line comments (// and #)
        applyRegex("//[^\n]*", to: result, in: nsText, color: commentColor)
        applyRegex("#[^\n]*", to: result, in: nsText, color: commentColor)

        // Highlight multi-line comments /* ... */
        applyRegex("/\\*[\\s\\S]*?\\*/", to: result, in: nsText, color: commentColor)

        // Highlight strings (double-quoted and single-quoted, non-greedy)
        applyRegex("\"(?:[^\"\\\\]|\\\\.)*\"", to: result, in: nsText, color: stringColor)
        applyRegex("'(?:[^'\\\\]|\\\\.)*'", to: result, in: nsText, color: stringColor)

        // Highlight numbers
        applyRegex("\\b\\d+(\\.\\d+)?\\b", to: result, in: nsText, color: numberColor)

        // Highlight keywords (word-boundary match)
        for keyword in keywords {
            applyRegex("\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b",
                        to: result, in: nsText, color: keywordColor)
        }

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
