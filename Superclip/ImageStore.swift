//
//  ImageStore.swift
//  Superclip
//

import AppKit
import Foundation

/// Manages on-disk storage for clipboard image data.
///
/// Images are stored as individual files in
/// `~/Library/Application Support/Superclip/images/{UUID}.dat`.
/// This keeps `history.json` small and avoids holding large blobs in memory.
class ImageStore {

    static let shared = ImageStore()

    private let directory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("Superclip/images", isDirectory: true)

        // Create the images directory if it doesn't exist
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Atomically write image data to `{UUID}.dat`.
    func save(data: Data, for id: UUID) {
        let url = fileURL(for: id)
        try? data.write(to: url, options: .atomic)
    }

    /// Read raw image bytes from disk. Returns `nil` if the file doesn't exist.
    func loadData(for id: UUID) -> Data? {
        let url = fileURL(for: id)
        return try? Data(contentsOf: url)
    }

    /// Read only the first N bytes from an image file (e.g. for magic-number format detection).
    func loadHeader(for id: UUID, byteCount: Int) -> Data? {
        let url = fileURL(for: id)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }
        let data = handle.readData(ofLength: byteCount)
        return data.isEmpty ? nil : data
    }

    /// Check whether an image file exists on disk for the given ID.
    func exists(for id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: id).path)
    }

    /// Remove the image file for a single item.
    func delete(for id: UUID) {
        let url = fileURL(for: id)
        try? FileManager.default.removeItem(at: url)
    }

    /// Remove image files that are not in the provided set of valid IDs.
    /// Recently written files are skipped: `validIDs` is a snapshot, and a
    /// capture landing between snapshot and enumeration must not be deleted.
    func cleanupOrphans(keeping validIDs: Set<UUID>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        for fileURL in contents {
            if let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               Date().timeIntervalSince(modified) < 300 {
                continue
            }
            let name = fileURL.deletingPathExtension().lastPathComponent
            guard let fileID = UUID(uuidString: name) else {
                // Not a UUID-named file — remove it
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }
            if !validIDs.contains(fileID) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    /// Wipe the entire images directory (used by "clear history").
    func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
        // Re-create the empty directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).dat")
    }
}

// MARK: - RTF Store

/// On-disk storage for RTF data, mirroring ImageStore's design.
/// Files live in ~/Library/Application Support/Superclip/rtf/{UUID}.rtf
class RTFStore {
    static let shared = RTFStore()

    private let directory: URL

    /// Parsed-attributed-string cache. Card/preview bodies read
    /// `item.attributedString` on every SwiftUI evaluation; without this,
    /// each evaluation is a disk read plus a full RTF parse on the main
    /// thread. Invalidated on save/delete since edits reuse the item ID.
    private let attributedCache: NSCache<NSUUID, NSAttributedString> = {
        let c = NSCache<NSUUID, NSAttributedString>()
        c.countLimit = 40
        return c
    }()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("Superclip/rtf", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(data: Data, for id: UUID) {
        attributedCache.removeObject(forKey: id as NSUUID)
        try? data.write(to: fileURL(for: id), options: .atomic)
    }

    func loadData(for id: UUID) -> Data? {
        try? Data(contentsOf: fileURL(for: id))
    }

    /// Load and parse the RTF for an item, memoized.
    func attributedString(for id: UUID) -> NSAttributedString? {
        let key = id as NSUUID
        if let cached = attributedCache.object(forKey: key) { return cached }
        guard let data = loadData(for: id),
              let parsed = NSAttributedString(rtf: data, documentAttributes: nil) else { return nil }
        attributedCache.setObject(parsed, forKey: key)
        return parsed
    }

    func exists(for id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: id).path)
    }

    func delete(for id: UUID) {
        attributedCache.removeObject(forKey: id as NSUUID)
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    func cleanupOrphans(keeping validIDs: Set<UUID>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for file in contents {
            // Skip recently written files — see ImageStore.cleanupOrphans.
            if let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               Date().timeIntervalSince(modified) < 300 {
                continue
            }
            let name = file.deletingPathExtension().lastPathComponent
            guard let fileID = UUID(uuidString: name) else {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            if !validIDs.contains(fileID) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func deleteAll() {
        attributedCache.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).rtf")
    }
}
