//
//  FuzzySearch.swift
//  Superclip
//

import Foundation

/// Lightweight fuzzy search with ranked results.
/// Matches on content, source app name, type label, and file names.
/// Scoring: exact > prefix > contains > fuzzy (subsequence).
enum FuzzySearch {

    struct ScoredItem {
        let item: ClipboardItem
        let score: Int
    }

    /// Filter and rank items by query. Returns items sorted by relevance (highest first).
    static func search(query: String, in items: [ClipboardItem]) -> [ClipboardItem] {
        let query = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }

        var scored: [ScoredItem] = []

        for item in items {
            let bestScore = scoreItem(item, query: query)
            if bestScore > 0 {
                scored.append(ScoredItem(item: item, score: bestScore))
            }
        }

        // Sort by score descending, then by timestamp descending (recency as tiebreaker)
        scored.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.item.timestamp > b.item.timestamp
        }

        return scored.map(\.item)
    }

    // MARK: - Scoring

    private static func scoreItem(_ item: ClipboardItem, query: String) -> Int {
        var bestScore = 0

        // Score against main content
        bestScore = max(bestScore, scoreString(item.content.lowercased(), query: query, weight: 10))

        // Score against source app name
        if let appName = item.sourceApp?.name.lowercased() {
            bestScore = max(bestScore, scoreString(appName, query: query, weight: 6))
        }

        // Score against source app bundle ID
        if let bundleId = item.sourceApp?.bundleIdentifier?.lowercased() {
            // Extract app name from bundle ID (e.g., "com.apple.safari" -> "safari")
            let appPart = bundleId.split(separator: ".").last.map(String.init) ?? bundleId
            bestScore = max(bestScore, scoreString(appPart, query: query, weight: 5))
        }

        // Score against type label
        bestScore = max(bestScore, scoreString(item.typeLabel.lowercased(), query: query, weight: 4))

        // Score against file names
        if let urls = item.fileURLs {
            for url in urls {
                bestScore = max(bestScore, scoreString(url.lastPathComponent.lowercased(), query: query, weight: 7))
            }
        }

        // Score against link metadata title
        if let title = item.linkMetadata?.title?.lowercased() {
            bestScore = max(bestScore, scoreString(title, query: query, weight: 8))
        }

        return bestScore
    }

    /// Score a string against a query. Higher = better match.
    /// Weight multiplies the base score (allows prioritizing certain fields).
    private static func scoreString(_ text: String, query: String, weight: Int) -> Int {
        guard !text.isEmpty else { return 0 }

        // Exact match (highest)
        if text == query {
            return 100 * weight
        }

        // Exact contains
        if text.contains(query) {
            // Bonus for prefix match
            if text.hasPrefix(query) {
                return 80 * weight
            }
            // Bonus for word-boundary match
            if text.contains(" \(query)") || text.contains(".\(query)") || text.contains("/\(query)") {
                return 70 * weight
            }
            return 60 * weight
        }

        // Fuzzy: check if query chars appear in order (subsequence match)
        if fuzzyMatch(text: text, query: query) {
            // Score based on how compact the match is
            let compactness = fuzzyCompactness(text: text, query: query)
            return Int(Double(40 * weight) * compactness)
        }

        return 0
    }

    /// Check if all characters of query appear in text in order.
    private static func fuzzyMatch(text: String, query: String) -> Bool {
        var textIndex = text.startIndex
        var queryIndex = query.startIndex

        while textIndex < text.endIndex && queryIndex < query.endIndex {
            if text[textIndex] == query[queryIndex] {
                queryIndex = query.index(after: queryIndex)
            }
            textIndex = text.index(after: textIndex)
        }

        return queryIndex == query.endIndex
    }

    /// How compact the fuzzy match is (1.0 = characters are adjacent, lower = more spread out).
    private static func fuzzyCompactness(text: String, query: String) -> Double {
        guard query.count > 1 else { return 1.0 }

        var textIndex = text.startIndex
        var queryIndex = query.startIndex
        var firstMatchPos: Int?
        var lastMatchPos: Int = 0
        var pos = 0

        while textIndex < text.endIndex && queryIndex < query.endIndex {
            if text[textIndex] == query[queryIndex] {
                if firstMatchPos == nil { firstMatchPos = pos }
                lastMatchPos = pos
                queryIndex = query.index(after: queryIndex)
            }
            textIndex = text.index(after: textIndex)
            pos += 1
        }

        guard let first = firstMatchPos else { return 0 }
        let span = lastMatchPos - first + 1
        // Best case: span == query.count (all chars adjacent)
        return Double(query.count) / Double(max(span, query.count))
    }
}
