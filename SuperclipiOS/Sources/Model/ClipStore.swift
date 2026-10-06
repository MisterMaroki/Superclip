//
//  ClipStore.swift
//  Superclip for iPhone
//
//  The app's single source of truth. Everything is stored on the device as
//  one JSON file plus an images folder. Sync with the Mac plugs in here later:
//  every mutation already goes through this type.
//

import SwiftUI
import UIKit

enum SyncState: Equatable {
    /// Sync is off, or cannot run; clips stay on this iPhone.
    case localOnly
    case syncing
    case upToDate(Date)

    var label: String {
        switch self {
        case .localOnly: return "On this iPhone"
        case .syncing: return "Syncing"
        case .upToDate: return "Synced with iCloud"
        }
    }
}

@MainActor
final class ClipStore: ObservableObject {
    @Published private(set) var clips: [Clip] = []
    @Published private(set) var pinboards: [Pinboard] = []
    @Published private(set) var snippets: [Snippet] = []
    @Published var syncState: SyncState = .localOnly
    /// A sentence about sync for Settings (why it is off, or that it is working).
    @Published var syncDetail = "Clips you save stay on this iPhone."

    /// Called when the user deletes records (not when a deletion arrives from sync).
    var onUserDeleted: (([SyncKey]) -> Void)?

    /// The most recent toast, shown by the root view.
    @Published var toast: Toast?

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        var undo: UndoAction?

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    enum UndoAction {
        case restore(Clip, pinnedIn: [UUID])
    }

    private struct Snapshot: Codable {
        var clips: [Clip]
        var pinboards: [Pinboard]
        var snippets: [Snippet]
    }

    private let directory: URL
    private var fileURL: URL { directory.appendingPathComponent("library.json") }
    private var imagesDirectory: URL { directory.appendingPathComponent("images", isDirectory: true) }
    private var saveTask: Task<Void, Never>?

    init(directory: URL? = nil) {
        let base =
            directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Superclip", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base.appendingPathComponent("images"), withIntermediateDirectories: true)
        load()
    }

    // MARK: Queries

    func clips(in pinboard: Pinboard?, kind: ClipKind?, matching query: String) -> [Clip] {
        var result = clips
        if let pinboard {
            let ids = Set(pinboard.clipIDs)
            result = result.filter { ids.contains($0.id) }
        }
        if let kind {
            result = result.filter { $0.kind == kind }
        }
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !needle.isEmpty {
            result = result.filter {
                $0.content.lowercased().contains(needle)
                    || ($0.title?.lowercased().contains(needle) ?? false)
                    || ($0.sourceApp?.lowercased().contains(needle) ?? false)
            }
        }
        return result
    }

    func pinboards(containing clip: Clip) -> [Pinboard] {
        pinboards.filter { $0.clipIDs.contains(clip.id) }
    }

    func image(for clip: Clip) -> UIImage? {
        guard let name = clip.imageFile else { return nil }
        return UIImage(contentsOfFile: imagesDirectory.appendingPathComponent(name).path)
    }

    // MARK: Using clips

    /// Put a clip on the system clipboard and move it to the top.
    func copy(_ clip: Clip, plainText: Bool = false) {
        switch clip.kind {
        case .image:
            if let image = image(for: clip) { UIPasteboard.general.image = image }
        case .link where !plainText:
            if let url = URL(string: clip.content) {
                UIPasteboard.general.url = url
            } else {
                UIPasteboard.general.string = clip.content
            }
        default:
            UIPasteboard.general.string = clip.content
        }
        touch(clip)
        toast = Toast(text: plainText ? "Copied as plain text" : "Copied")
    }

    private func touch(_ clip: Clip) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        var updated = clips.remove(at: index)
        updated.lastUsedAt = Date()
        clips.insert(updated, at: 0)
        scheduleSave()
    }

    // MARK: Adding clips

    /// Save text the user pasted or shared in. Returns false if it was already there.
    @discardableResult
    func capture(text: String, sourceApp: String? = nil) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if let existing = clips.first(where: { $0.content == text }) {
            touch(existing)
            toast = Toast(text: "Already saved. Moved to the top.")
            return false
        }
        let clip = Clip(
            kind: ClipClassifier.kind(of: text), content: text, sourceApp: sourceApp,
            device: Clip.thisDevice)
        clips.insert(clip, at: 0)
        scheduleSave()
        toast = Toast(text: "Saved to Superclip")
        return true
    }

    func capture(image: UIImage) {
        saveImage(image)
        scheduleSave()
        toast = Toast(text: "Saved to Superclip")
    }

    private func saveImage(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        let name = UUID().uuidString + ".png"
        try? data.write(to: imagesDirectory.appendingPathComponent(name), options: .atomic)
        let width = Int(image.size.width * image.scale), height = Int(image.size.height * image.scale)
        let clip = Clip(
            kind: .image, content: "\(width)\u{00D7}\(height)", imageFile: name,
            imageWidth: width, imageHeight: height, device: Clip.thisDevice)
        clips.insert(clip, at: 0)
    }

    // MARK: Deleting

    func delete(_ clip: Clip) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        let pinnedIn = pinboards(containing: clip).map(\.id)
        clips.remove(at: index)
        for i in pinboards.indices where pinboards[i].clipIDs.contains(clip.id) {
            pinboards[i].clipIDs.removeAll { $0 == clip.id }
            pinboards[i].modifiedAt = Date()
        }
        scheduleSave()
        toast = Toast(text: "Deleted", undo: .restore(clip, pinnedIn: pinnedIn))
        onUserDeleted?([SyncKey(.clip, clip.id)])
    }

    func perform(_ undo: UndoAction) {
        switch undo {
        case .restore(let clip, let pinnedIn):
            guard !clips.contains(where: { $0.id == clip.id }) else { return }
            let index = clips.firstIndex(where: { $0.lastUsedAt < clip.lastUsedAt }) ?? clips.count
            clips.insert(clip, at: index)
            for i in pinboards.indices where pinnedIn.contains(pinboards[i].id) {
                pinboards[i].clipIDs.append(clip.id)
                pinboards[i].modifiedAt = Date()
            }
            scheduleSave()
            toast = Toast(text: "Restored")
        }
    }

    // MARK: Pinboards

    func isPinned(_ clip: Clip, in pinboard: Pinboard) -> Bool {
        pinboard.clipIDs.contains(clip.id)
    }

    func togglePin(_ clip: Clip, in pinboard: Pinboard) {
        guard let index = pinboards.firstIndex(where: { $0.id == pinboard.id }) else { return }
        if let existing = pinboards[index].clipIDs.firstIndex(of: clip.id) {
            pinboards[index].clipIDs.remove(at: existing)
            toast = Toast(text: "Removed from \(pinboard.name)")
        } else {
            pinboards[index].clipIDs.append(clip.id)
            toast = Toast(text: "Pinned to \(pinboard.name)")
        }
        pinboards[index].modifiedAt = Date()
        scheduleSave()
    }

    @discardableResult
    func addPinboard(name: String, tint: PinTint) -> Pinboard {
        let board = Pinboard(name: name.isEmpty ? "Untitled" : name, tint: tint, modifiedAt: Date())
        pinboards.append(board)
        scheduleSave()
        return board
    }

    func update(_ pinboard: Pinboard) {
        guard let index = pinboards.firstIndex(where: { $0.id == pinboard.id }) else { return }
        pinboards[index] = pinboard
        pinboards[index].modifiedAt = Date()
        scheduleSave()
    }

    func delete(_ pinboard: Pinboard) {
        pinboards.removeAll { $0.id == pinboard.id }
        scheduleSave()
        onUserDeleted?([SyncKey(.pinboard, pinboard.id)])
    }

    // MARK: Snippets

    func save(_ snippet: Snippet) {
        var snippet = snippet
        snippet.modifiedAt = Date()
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
        } else {
            snippets.append(snippet)
        }
        scheduleSave()
    }

    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        scheduleSave()
        onUserDeleted?([SyncKey(.snippet, snippet.id)])
    }

    func copy(_ snippet: Snippet) {
        UIPasteboard.general.string = snippet.content
        toast = Toast(text: "Copied \(snippet.name)")
    }

    // MARK: Sync and sharing (no toasts: these are not things the user just did here)

    func imageData(for clip: Clip) -> Data? {
        guard let name = clip.imageFile else { return nil }
        return try? Data(contentsOf: imagesDirectory.appendingPathComponent(name))
    }

    /// Insert or replace a clip that arrived from iCloud, keeping newest-first order.
    func syncUpsert(_ clip: Clip, imageData: Data?) {
        var clip = clip
        if let imageData {
            let name = clip.imageFile ?? (clip.id.uuidString + ".img")
            try? imageData.write(to: imagesDirectory.appendingPathComponent(name), options: .atomic)
            clip.imageFile = name
        } else if clip.imageFile == nil {
            clip.imageFile = clips.first(where: { $0.id == clip.id })?.imageFile
        }
        clips.removeAll { $0.id == clip.id }
        let index = clips.firstIndex(where: { $0.lastUsedAt < clip.lastUsedAt }) ?? clips.count
        clips.insert(clip, at: index)
        scheduleSave()
    }

    func syncRemoveClips(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for clip in clips where ids.contains(clip.id) {
            if let name = clip.imageFile {
                try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(name))
            }
        }
        clips.removeAll { ids.contains($0.id) }
        for i in pinboards.indices { pinboards[i].clipIDs.removeAll { ids.contains($0) } }
        scheduleSave()
    }

    func syncUpsert(_ pinboard: Pinboard, position: Int) {
        pinboards.removeAll { $0.id == pinboard.id }
        pinboards.insert(pinboard, at: min(max(position, 0), pinboards.count))
        scheduleSave()
    }

    func syncRemovePinboard(_ id: UUID) {
        pinboards.removeAll { $0.id == id }
        scheduleSave()
    }

    func syncUpsert(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
        } else {
            snippets.append(snippet)
        }
        scheduleSave()
    }

    func syncRemoveSnippet(_ id: UUID) {
        snippets.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Point pins at a different clip (two copies of the same clip were merged).
    func syncReplaceClip(_ old: UUID, with new: UUID) {
        for i in pinboards.indices where pinboards[i].clipIDs.contains(old) {
            pinboards[i].clipIDs = SyncMerge.remap(pinboards[i].clipIDs, replacing: old, with: new)
        }
        scheduleSave()
    }

    /// Bring in what the share extension saved while the app was closed.
    func importSharedInbox() {
        let items = SharedInbox.drain()
        guard !items.isEmpty else { return }
        var added = 0
        for item in items {
            if let imageData = item.imageData, let image = UIImage(data: imageData) {
                saveImage(image)
                added += 1
            } else if let text = item.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !clips.contains(where: { $0.content == text })
            {
                var clip = Clip(
                    kind: ClipClassifier.kind(of: text), content: text, title: item.title,
                    sourceApp: "Shared", device: Clip.thisDevice)
                clip.createdAt = item.date
                clip.lastUsedAt = item.date
                clips.insert(clip, at: 0)
                added += 1
            }
        }
        guard added > 0 else { return }
        clips.sort { $0.lastUsedAt > $1.lastUsedAt }
        scheduleSave()
        toast = Toast(text: added == 1 ? "Saved 1 shared clip" : "Saved \(added) shared clips")
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
            let snapshot = try? JSONDecoder.superclip.decode(Snapshot.self, from: data)
        else { return }
        clips = snapshot.clips.sorted { $0.lastUsedAt > $1.lastUsedAt }
        pinboards = snapshot.pinboards
        snippets = snapshot.snippets
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = Snapshot(clips: clips, pinboards: pinboards, snippets: snippets)
        let url = fileURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let data = try? JSONEncoder.superclip.encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    var isEmpty: Bool { clips.isEmpty && pinboards.isEmpty && snippets.isEmpty }

    /// Replace everything with the sample library (first launch, and "Load sample data").
    func loadSampleLibrary() {
        let sample = SampleLibrary.make(imagesDirectory: imagesDirectory)
        clips = sample.clips
        pinboards = sample.pinboards
        snippets = sample.snippets
        scheduleSave()
    }

    func eraseEverything() {
        // With sync on this is a deletion like any other: it reaches iCloud
        // and the Mac too. The confirmation dialog says so.
        onUserDeleted?(
            clips.map { SyncKey(.clip, $0.id) } + pinboards.map { SyncKey(.pinboard, $0.id) }
                + snippets.map { SyncKey(.snippet, $0.id) })
        clips = []
        pinboards = []
        snippets = []
        try? FileManager.default.removeItem(at: imagesDirectory)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        scheduleSave()
    }
}

extension JSONEncoder {
    static let superclip: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let superclip: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
