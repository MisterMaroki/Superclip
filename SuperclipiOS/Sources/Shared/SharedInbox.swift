//
//  SharedInbox.swift
//  Superclip for iPhone (app and share extension)
//
//  How the share extension hands clips to the app. The extension cannot reach
//  the app's own data, so it drops each shared item into a folder both can
//  see (the app group container), and the app collects them when it next opens.
//

import Foundation

enum SharedInbox {
    static let appGroup = "group.com.omarmaroki.Superclip"

    struct Item: Codable {
        var id = UUID()
        var date = Date()
        /// Shared text, or a URL as text.
        var text: String?
        /// Page title, when a link was shared with one.
        var title: String?
        var imageData: Data?
    }

    /// Nil when the app group is not available (the build is not signed for it).
    private static var directory: URL? {
        guard
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        else { return nil }
        let inbox = container.appendingPathComponent("inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    static var isAvailable: Bool { directory != nil }

    /// Save one shared item. Returns false if it could not be written.
    @discardableResult
    static func add(_ item: Item) -> Bool {
        guard let directory, let data = try? JSONEncoder().encode(item) else { return false }
        let file = directory.appendingPathComponent(item.id.uuidString + ".json")
        return (try? data.write(to: file, options: .atomic)) != nil
    }

    /// Read everything waiting, oldest first, and empty the folder.
    static func drain() -> [Item] {
        guard let directory,
            let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }
        var items: [Item] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file), let item = try? JSONDecoder().decode(Item.self, from: data) {
                items.append(item)
            }
            try? FileManager.default.removeItem(at: file)
        }
        return items.sorted { $0.date < $1.date }
    }
}
