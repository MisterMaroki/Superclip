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
        let normalized = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return items }

        var scored: [ScoredItem] = []
        let query = Query(normalized)

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

    /// The query plus the variants every item is tested against, built once
    /// per search instead of once per item.
    private struct Query {
        let text: String
        let afterSpace: String
        let afterDot: String
        let afterSlash: String

        init(_ text: String) {
            self.text = text
            afterSpace = " " + text
            afterDot = "." + text
            afterSlash = "/" + text
        }
    }

    /// Only this much of a clip is searched. Matching megabytes of a pasted
    /// log on every keystroke is what made search stutter on large histories.
    private static let maxSearchedLength = 20_000

    /// Above this length the loose "letters appear in order" match is skipped:
    /// in a long text almost any short query matches that way, so it only adds
    /// noise and cost.
    private static let maxFuzzyLength = 2_000

    /// Lowercased search text per clip, cached so it is not rebuilt for every
    /// item on every keystroke.
    private static let lowercasedCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 3_000
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    private static func searchText(for content: String) -> String {
        let key = content as NSString
        if let cached = lowercasedCache.object(forKey: key) { return cached as String }
        let lowered = (content.utf16.count > maxSearchedLength
            ? String(content.prefix(maxSearchedLength)) : content).lowercased()
        lowercasedCache.setObject(lowered as NSString, forKey: key, cost: lowered.utf8.count)
        return lowered
    }

    private static func scoreItem(_ item: ClipboardItem, query: Query) -> Int {
        var bestScore = 0

        // Score against main content
        bestScore = max(bestScore, scoreString(searchText(for: item.content), query: query, weight: 10))

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
    private static func scoreString(_ text: String, query: Query, weight: Int) -> Int {
        guard !text.isEmpty else { return 0 }

        // Exact match (highest)
        if text == query.text {
            return 100 * weight
        }

        // Exact contains
        if text.contains(query.text) {
            // Bonus for prefix match
            if text.hasPrefix(query.text) {
                return 80 * weight
            }
            // Bonus for word-boundary match
            if text.contains(query.afterSpace) || text.contains(query.afterDot)
                || text.contains(query.afterSlash)
            {
                return 70 * weight
            }
            return 60 * weight
        }

        // Fuzzy: check if query chars appear in order (subsequence match)
        if text.utf8.count <= maxFuzzyLength, let compactness = fuzzyCompactness(text: text, query: query.text) {
            return Int(Double(40 * weight) * compactness)
        }

        return 0
    }

    /// If every unit of `query` appears in `text` in order, how compact that
    /// match is (1.0 = adjacent, lower = more spread out); nil if it does not
    /// match. Walks UTF-8 bytes: indexing by Character was the slow part of
    /// search, and a byte-wise subsequence gives the same answer.
    private static func fuzzyCompactness(text: String, query: String) -> Double? {
        let queryBytes = Array(query.utf8)
        guard !queryBytes.isEmpty else { return nil }

        var queryIndex = 0
        var firstMatchPos: Int?
        var lastMatchPos = 0
        var pos = 0

        for byte in text.utf8 {
            if byte == queryBytes[queryIndex] {
                if firstMatchPos == nil { firstMatchPos = pos }
                lastMatchPos = pos
                queryIndex += 1
                if queryIndex == queryBytes.count { break }
            }
            pos += 1
        }

        guard queryIndex == queryBytes.count, let first = firstMatchPos else { return nil }
        guard queryBytes.count > 1 else { return 1.0 }
        let span = lastMatchPos - first + 1
        // Best case: span == query length (all adjacent)
        return Double(queryBytes.count) / Double(max(span, queryBytes.count))
    }
}
