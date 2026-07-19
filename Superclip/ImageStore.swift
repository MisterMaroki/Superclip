//
//  ImageStore.swift
//  Superclip
//

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
    func cleanupOrphans(keeping validIDs: Set<UUID>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in contents {
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

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("Superclip/rtf", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(data: Data, for id: UUID) {
        try? data.write(to: fileURL(for: id), options: .atomic)
    }

    func loadData(for id: UUID) -> Data? {
        try? Data(contentsOf: fileURL(for: id))
    }

    func exists(for id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: id).path)
    }

    func delete(for id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    func cleanupOrphans(keeping validIDs: Set<UUID>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in contents {
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
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).rtf")
    }
}
