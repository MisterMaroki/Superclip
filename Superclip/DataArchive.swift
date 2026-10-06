//
//  DataArchive.swift
//  Superclip
//
//  Export and import of clipboard history, pinboards and snippets as a single
//  JSON file. Importing merges into what is already there; it never replaces
//  or deletes existing data.
//

import Foundation

/// On-disk format of an export. Versioned so later releases can still read it.
struct SuperclipArchive: Codable {
    static let currentVersion = 1

    var version: Int = SuperclipArchive.currentVersion
    var exportedAt: Date = Date()
    var items: [CodableClipboardItem]
    /// Image bytes for image clips, keyed by the clip's UUID string.
    var images: [String: Data]
    /// RTF for rich-text clips, keyed by the clip's UUID string.
    var richText: [String: Data]
    var pinboards: [Pinboard]
    var snippets: [Snippet]
}

enum DataArchiveError: LocalizedError {
    case unreadable
    case newerVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "This file isn\u{2019}t a Superclip export, or it is damaged."
        case .newerVersion(let version):
            return "This export was made by a newer version of Superclip (format \(version)). Update Superclip to import it."
        }
    }
}

enum DataArchive {

    struct ImportSummary {
        let items: Int
        let pinboards: Int
        let snippets: Int

        var isEmpty: Bool { items == 0 && pinboards == 0 && snippets == 0 }

        var description: String {
            func count(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }
            if isEmpty { return "Everything in this file was already in Superclip." }
            return "Added \(count(items, "clip")), \(count(pinboards, "pinboard")) and \(count(snippets, "snippet")). Anything you already had was left as it was."
        }
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Build an export of everything currently stored.
    static func export(
        clipboard: ClipboardManager, pinboards: PinboardManager, snippets: SnippetManager
    ) throws -> Data {
        var images: [String: Data] = [:]
        var richText: [String: Data] = [:]
        for item in clipboard.history {
            if item.hasImage, let data = ImageStore.shared.loadData(for: item.id) {
                images[item.id.uuidString] = data
            }
            if item.hasRTF, let data = RTFStore.shared.loadData(for: item.id) {
                richText[item.id.uuidString] = data
            }
        }
        let archive = SuperclipArchive(
            items: clipboard.history.map { CodableClipboardItem(from: $0) },
            images: images,
            richText: richText,
            pinboards: pinboards.pinboards,
            snippets: snippets.snippets
        )
        return try encoder().encode(archive)
    }

    /// Merge an export into the current data. Existing clips, pinboards and
    /// snippets are never changed or removed.
    static func importArchive(
        _ data: Data, clipboard: ClipboardManager, pinboards: PinboardManager,
        snippets: SnippetManager
    ) throws -> ImportSummary {
        guard let archive = try? decoder().decode(SuperclipArchive.self, from: data) else {
            throw DataArchiveError.unreadable
        }
        guard archive.version <= SuperclipArchive.currentVersion else {
            throw DataArchiveError.newerVersion(archive.version)
        }

        // Put image and rich-text files back before the clips that point at them
        for codable in archive.items {
            let key = codable.id.uuidString
            if codable.hasImage, let bytes = archive.images[key], !ImageStore.shared.exists(for: codable.id) {
                ImageStore.shared.save(data: bytes, for: codable.id)
            }
            if codable.hasRTF, let bytes = archive.richText[key], !RTFStore.shared.exists(for: codable.id) {
                RTFStore.shared.save(data: bytes, for: codable.id)
            }
        }

        let merge = clipboard.mergeImported(archive.items.map { $0.toClipboardItem() })
        let addedPinboards = pinboards.mergeImported(archive.pinboards, remappingItemIds: merge.idMap)
        let addedSnippets = snippets.mergeImported(archive.snippets)
        return ImportSummary(items: merge.added, pinboards: addedPinboards, snippets: addedSnippets)
    }
}
