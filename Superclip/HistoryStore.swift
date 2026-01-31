//
//  HistoryStore.swift
//  Superclip
//

import Foundation
import Combine

/// Handles persisting clipboard history to disk as JSON.
///
/// Storage location: ~/Library/Application Support/Superclip/history.json
/// Saves are debounced (~1.5 seconds) to avoid excessive writes on rapid clipboard changes.
class HistoryStore {

    // MARK: - Properties

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Combine subject used to debounce save requests.
    private let saveSubject = PassthroughSubject<Void, Never>()
    private var cancellable: AnyCancellable?

    // MARK: - Init

    init() {
        // ~/Library/Application Support/Superclip/history.json
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let superclipDir = appSupport.appendingPathComponent("Superclip", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: superclipDir, withIntermediateDirectories: true)

        self.fileURL = superclipDir.appendingPathComponent("history.json")

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        // Debounce: collect save requests and flush after 1.5 seconds of inactivity
        cancellable = saveSubject
            .debounce(for: .milliseconds(1500), scheduler: DispatchQueue.global(qos: .utility))
            .sink { [weak self] in
                self?.flushPendingSave()
            }
    }

    // MARK: - Public API

    /// Load history from disk. Returns an empty array if no file exists or decoding fails.
    func load() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let codableItems = try decoder.decode([CodableClipboardItem].self, from: data)
            return codableItems.map { $0.toClipboardItem() }
        } catch {
            // If the file is corrupted, log and return empty
            print("[HistoryStore] Failed to load history: \(error)")
            return []
        }
    }

    /// Schedule a debounced save. Safe to call frequently.
    func scheduleSave(items: [ClipboardItem]) {
        // Capture the items immediately (snapshot) on the calling thread,
        // then hand off to the debounce pipeline.
        let codableItems = items.map { CodableClipboardItem(from: $0) }
        pendingItems = codableItems
        saveSubject.send()
    }

    /// Immediately write history to disk (bypass debounce).
    /// Use this on app termination to avoid data loss.
    func saveImmediately(items: [ClipboardItem]) {
        let codableItems = items.map { CodableClipboardItem(from: $0) }
        write(codableItems)
    }

    /// Delete the history file from disk.
    func deleteHistoryFile() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Private

    /// Latest snapshot waiting to be flushed. Protected by a lock for thread safety.
    private var pendingItems: [CodableClipboardItem]?
    private let lock = NSLock()

    private func flushPendingSave() {
        lock.lock()
        let items = pendingItems
        pendingItems = nil
        lock.unlock()

        guard let items = items else { return }
        write(items)
    }

    private func write(_ items: [CodableClipboardItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[HistoryStore] Failed to save history: \(error)")
        }
    }
}
