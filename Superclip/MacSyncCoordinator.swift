//
//  MacSyncCoordinator.swift
//  Superclip
//
//  Connects the Mac app's own storage to the shared sync engine, in both
//  directions: it notices local changes and queues them for upload, and it
//  merges what arrives from iCloud into history, pinboards and snippets.
//
//  The existing stores stay the source of truth. With sync off, or iCloud
//  unavailable, the app behaves exactly as it did before.
//

import AppKit
import Combine
import Foundation

@MainActor
final class MacSyncCoordinator: ObservableObject {

    /// The running coordinator, for views that only need to show its status.
    static private(set) weak var current: MacSyncCoordinator?

    @Published private(set) var status: CloudSyncEngine.Status = .off

    private let clipboard: ClipboardManager
    private let pinboards: PinboardManager
    private let snippets: SnippetManager
    private let settings: SettingsManager

    private var engine: CloudSyncEngine?
    private var tracker = SyncChangeTracker()
    private var meta = Meta()
    private var isApplyingRemote = false
    private var cancellables = Set<AnyCancellable>()
    private var changeSubscription: AnyCancellable?

    private let deviceName = Host.current().localizedName ?? "Mac"

    /// Sync facts the Mac's own model has no field for.
    private struct Meta: Codable {
        struct Clip: Codable {
            var device: String
            var createdAt: Date
            var modifiedAt: Date
            var contentHash: String
        }
        var clips: [UUID: Clip] = [:]
        var pinboardModified: [UUID: Date] = [:]
        var snippetModified: [UUID: Date] = [:]
    }

    private let directory: URL

    init(clipboard: ClipboardManager, pinboards: PinboardManager, snippets: SnippetManager, settings: SettingsManager) {
        self.clipboard = clipboard
        self.pinboards = pinboards
        self.snippets = snippets
        self.settings = settings
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = appSupport.appendingPathComponent("Superclip/sync", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        loadMeta()
        Self.current = self

        // User deletions are reported explicitly. A clip that merely drops out
        // of history (trimming) is not deleted everywhere.
        let existingPurgeHandler = clipboard.onItemsPurged
        clipboard.onItemsPurged = { [weak self] ids in
            existingPurgeHandler?(ids)
            self?.userDeleted(ids.map { SyncKey(.clip, $0) })
        }
        pinboards.onPinboardsDeleted = { [weak self] ids in
            self?.userDeleted(ids.map { SyncKey(.pinboard, $0) })
        }
        snippets.onSnippetsDeleted = { [weak self] ids in
            self?.userDeleted(ids.map { SyncKey(.snippet, $0) })
        }

        settings.$syncEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                if enabled { self?.start() } else { self?.stop() }
            }
            .store(in: &cancellables)
    }

    // MARK: Lifecycle

    private func start() {
        guard engine == nil else { return }
        let engine = CloudSyncEngine(store: self, directory: directory)
        self.engine = engine
        engine.$status
            .sink { [weak self] in self?.status = $0 }
            .store(in: &cancellables)

        // Whatever exists now is either already in iCloud or about to be
        // queued by the engine's first run; only later changes are news.
        refreshMetaForLocalItems()
        tracker.acknowledge(currentSignatures())
        engine.start()

        changeSubscription = Publishers.Merge3(
            clipboard.$history.map { _ in () },
            pinboards.$pinboards.map { _ in () },
            snippets.$snippets.map { _ in () }
        )
        .debounce(for: .milliseconds(800), scheduler: DispatchQueue.main)
        .sink { [weak self] in self?.pushLocalChanges() }
    }

    private func stop() {
        changeSubscription = nil
        engine?.stop()
        // Start from scratch if sync is turned on again: changes made while
        // it was off would otherwise never be uploaded.
        engine?.resetCloudState()
        engine = nil
        status = .off
    }

    /// Queue anything not yet queued. Call before the app quits.
    func flush() {
        pushLocalChanges()
    }

    /// Check for changes now (the drawer was opened).
    func fetchNow() {
        engine?.fetchNow()
    }

    // MARK: Local changes -> cloud

    private func pushLocalChanges() {
        guard let engine, !isApplyingRemote else { return }
        let changed = tracker.changes(in: currentSignatures())
        guard !changed.isEmpty else { return }
        let now = Date()
        for key in changed {
            switch key.entity {
            case .clip:
                guard let item = clipboard.history.first(where: { $0.id == key.id }) else { continue }
                let hash = contentHash(of: item)
                if var existing = meta.clips[key.id] {
                    if existing.contentHash != hash {
                        existing.contentHash = hash
                        existing.modifiedAt = now
                        meta.clips[key.id] = existing
                    }
                } else {
                    meta.clips[key.id] = Meta.Clip(
                        device: deviceName, createdAt: item.timestamp, modifiedAt: item.timestamp, contentHash: hash)
                }
            case .pinboard:
                meta.pinboardModified[key.id] = now
            case .snippet:
                meta.snippetModified[key.id] = now
            }
        }
        saveMeta()
        engine.noteChanged(changed)
    }

    private func userDeleted(_ keys: [SyncKey]) {
        guard !isApplyingRemote else { return }
        for key in keys where key.entity == .clip { meta.clips[key.id] = nil }
        saveMeta()
        engine?.noteDeleted(keys)
    }

    /// Cheap fingerprints of everything that syncs, to spot what changed.
    private func currentSignatures() -> [SyncKey: Int] {
        var result: [SyncKey: Int] = [:]
        for item in clipboard.history where item.type != .file {
            var hasher = Hasher()
            hasher.combine(item.content)
            hasher.combine(item.timestamp)
            hasher.combine(item.linkMetadata?.title)
            hasher.combine(item.hasRTF)
            result[SyncKey(.clip, item.id)] = hasher.finalize()
        }
        for (index, board) in pinboards.pinboards.enumerated() {
            var hasher = Hasher()
            hasher.combine(board.name)
            hasher.combine(board.color.rawValue)
            hasher.combine(board.itemIds)
            hasher.combine(index)
            result[SyncKey(.pinboard, board.id)] = hasher.finalize()
        }
        for snippet in snippets.snippets {
            var hasher = Hasher()
            hasher.combine(snippet.name)
            hasher.combine(snippet.trigger)
            hasher.combine(snippet.content)
            hasher.combine(snippet.isEnabled)
            result[SyncKey(.snippet, snippet.id)] = hasher.finalize()
        }
        return result
    }

    private func refreshMetaForLocalItems() {
        for item in clipboard.history where item.type != .file && meta.clips[item.id] == nil {
            meta.clips[item.id] = Meta.Clip(
                device: deviceName, createdAt: item.timestamp, modifiedAt: item.timestamp,
                contentHash: contentHash(of: item))
        }
        saveMeta()
    }

    // MARK: Model conversion

    private func syncType(of item: ClipboardItem) -> SyncClipType? {
        switch item.type {
        case .text: return .text
        case .url: return .link
        case .image: return .image
        case .file: return nil  // a file path means nothing on another device
        }
    }

    private func contentHash(of item: ClipboardItem) -> String {
        switch item.type {
        case .image: return "image-" + (item.imageHash ?? item.id.uuidString)
        case .url: return SyncClip.hash(type: .link, content: item.content)
        default: return SyncClip.hash(type: .text, content: item.content)
        }
    }

    private func makeSyncClip(_ item: ClipboardItem) -> SyncClip? {
        guard let type = syncType(of: item) else { return nil }
        let info = meta.clips[item.id]
        var width: Int?, height: Int?
        if type == .image {
            let parts = item.content.split(separator: "\u{00D7}").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            }
            if parts.count == 2 { (width, height) = (parts[0], parts[1]) }
        }
        return SyncClip(
            id: item.id, type: type, content: item.content, title: item.linkMetadata?.title,
            createdAt: info?.createdAt ?? item.timestamp, lastUsedAt: item.timestamp,
            modifiedAt: info?.modifiedAt ?? item.timestamp, sourceApp: item.sourceApp?.name,
            sourceBundleID: item.sourceApp?.bundleIdentifier, device: info?.device ?? deviceName,
            imageWidth: width, imageHeight: height, contentHash: contentHash(of: item))
    }

    private func makeItem(from clip: SyncClip, existing: ClipboardItem?, hasImage: Bool, hasRTF: Bool) -> ClipboardItem {
        let type: ClipboardItem.ClipboardType
        switch clip.type {
        case .text: type = .text
        case .link: type = .url
        case .image: type = .image
        }
        var link: LinkMetadata? = existing?.linkMetadata
        if clip.type == .link, link == nil, let url = URL(string: clip.content), clip.title != nil {
            link = LinkMetadata(title: clip.title, url: url)
        }
        let source: SourceApp? =
            existing?.sourceApp
            ?? SourceApp(bundleIdentifier: clip.sourceBundleID, name: clip.sourceApp ?? clip.device, icon: nil)
        return ClipboardItem(
            id: clip.id, content: clip.content, timestamp: clip.lastUsedAt, type: type,
            hasImage: hasImage, imageHash: existing?.imageHash, fileURLs: nil, sourceApp: source,
            linkMetadata: link, hasRTF: hasRTF,
            detectedTags: type == .image ? [] : ContentDetector.detect(text: clip.content))
    }

    private func saveMeta() {
        guard let data = try? JSONEncoder().encode(meta) else { return }
        try? data.write(to: directory.appendingPathComponent("meta.json"), options: .atomic)
    }

    private func loadMeta() {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("meta.json")),
            let decoded = try? JSONDecoder().decode(Meta.self, from: data)
        else { return }
        meta = decoded
    }
}

// MARK: - CloudSyncStore

extension MacSyncCoordinator: CloudSyncStore {

    func syncClip(_ id: UUID) -> SyncClip? {
        clipboard.history.first(where: { $0.id == id }).flatMap(makeSyncClip)
    }

    func syncPinboard(_ id: UUID) -> SyncPinboard? {
        guard let index = pinboards.pinboards.firstIndex(where: { $0.id == id }) else { return nil }
        let board = pinboards.pinboards[index]
        return SyncPinboard(
            id: board.id, name: board.name, color: board.color.rawValue, position: index,
            clipIDs: board.itemIds, modifiedAt: meta.pinboardModified[id] ?? .distantPast)
    }

    func syncSnippet(_ id: UUID) -> SyncSnippet? {
        guard let snippet = snippets.snippets.first(where: { $0.id == id }) else { return nil }
        return SyncSnippet(
            id: snippet.id, name: snippet.name, trigger: snippet.trigger, content: snippet.content,
            isEnabled: snippet.isEnabled, modifiedAt: meta.snippetModified[id] ?? .distantPast)
    }

    func isPinned(_ clipID: UUID) -> Bool {
        pinboards.pinboards.contains { $0.itemIds.contains(clipID) }
    }

    func imageData(forClip id: UUID) -> Data? {
        ImageStore.shared.loadData(for: id)
    }

    func richTextData(forClip id: UUID) -> Data? {
        guard clipboard.history.first(where: { $0.id == id })?.hasRTF == true else { return nil }
        return RTFStore.shared.loadData(for: id)
    }

    func allSyncKeys() -> [SyncKey] {
        clipboard.history.filter { $0.type != .file }.map { SyncKey(.clip, $0.id) }
            + pinboards.pinboards.map { SyncKey(.pinboard, $0.id) }
            + snippets.snippets.map { SyncKey(.snippet, $0.id) }
    }

    func apply(_ changes: RemoteChanges) {
        isApplyingRemote = true
        /// Records whose merged result differs from what the cloud has, and
        /// so needs sending back.
        var reupload: [SyncKey] = []
        var dropped: [SyncKey] = []

        for entry in changes.clips {
            applyRemoteClip(entry, reupload: &reupload, dropped: &dropped)
        }

        for entry in changes.pinboards {
            let remote = entry.pinboard
            var merged = remote
            if let local = syncPinboard(remote.id) {
                let ancestor = entry.ancestorClipIDs.map {
                    SyncPinboard(id: remote.id, name: "", color: "", position: 0, clipIDs: $0, modifiedAt: .distantPast)
                }
                merged = SyncMerge.merge(local: local, remote: remote, ancestor: ancestor)
            }
            let board = Pinboard(
                id: merged.id, name: merged.name, color: PinboardColor(rawValue: merged.color) ?? .red,
                itemIds: merged.clipIDs)
            pinboards.applyRemote(board, position: merged.position)
            meta.pinboardModified[merged.id] = merged.modifiedAt
            if merged != remote { reupload.append(SyncKey(.pinboard, merged.id)) }
        }

        for remote in changes.snippets {
            var merged = remote
            if let local = syncSnippet(remote.id) {
                merged = SyncMerge.merge(local: local, remote: remote)
            }
            snippets.applyRemote(
                Snippet(id: merged.id, name: merged.name, trigger: merged.trigger, content: merged.content, isEnabled: merged.isEnabled))
            meta.snippetModified[merged.id] = merged.modifiedAt
            if merged != remote { reupload.append(SyncKey(.snippet, merged.id)) }
        }

        var deletedClips = Set<UUID>()
        for key in changes.deleted {
            switch key.entity {
            case .clip:
                // A clip that aged out of iCloud is not a clip the user
                // deleted: keep the local copy.
                if let local = syncClip(key.id),
                    SyncPolicy.isExpired(lastUsedAt: local.lastUsedAt, isPinned: isPinned(key.id))
                {
                    continue
                }
                deletedClips.insert(key.id)
                meta.clips[key.id] = nil
            case .pinboard:
                pinboards.applyRemoteDelete(key.id)
                meta.pinboardModified[key.id] = nil
            case .snippet:
                snippets.applyRemoteDelete(key.id)
                meta.snippetModified[key.id] = nil
            }
        }
        clipboard.applyRemoteDelete(deletedClips)
        pinboards.removeItems(Array(deletedClips))

        saveMeta()
        tracker.acknowledge(currentSignatures())
        isApplyingRemote = false

        engine?.noteChanged(reupload)
        engine?.noteDeleted(dropped)
    }

    private func applyRemoteClip(_ entry: RemoteChanges.Clip, reupload: inout [SyncKey], dropped: inout [SyncKey]) {
        let remote = entry.clip
        let existing = clipboard.history.first { $0.id == remote.id }

        // Same clip, both sides may have changed it
        if let existing, let local = makeSyncClip(existing) {
            let merged = SyncMerge.merge(local: local, remote: remote)
            store(entry, for: merged.id)
            let item = makeItem(
                from: merged, existing: existing,
                hasImage: existing.hasImage || entry.imageData != nil,
                hasRTF: entry.richText != nil || (existing.hasRTF && merged.content == existing.content))
            clipboard.applyRemote(item)
            meta.clips[merged.id] = Meta.Clip(
                device: merged.device, createdAt: merged.createdAt, modifiedAt: merged.modifiedAt,
                contentHash: merged.contentHash)
            if merged != remote { reupload.append(SyncKey(.clip, merged.id)) }
            return
        }

        // The same content already saved here under another ID by this Mac
        // (Universal Clipboard relayed one copy to both devices)
        if remote.type != .image,
            let twin = clipboard.history.first(where: { $0.type != .file && $0.content == remote.content }),
            let local = makeSyncClip(twin),
            let resolution = SyncMerge.resolveDuplicate(local, remote)
        {
            if resolution.keep.id == local.id {
                // Ours is the older one: keep it, drop theirs from iCloud
                clipboard.applyRemote(makeItem(from: resolution.keep, existing: twin, hasImage: twin.hasImage, hasRTF: twin.hasRTF))
                dropped.append(SyncKey(.clip, remote.id))
                reupload.append(SyncKey(.clip, local.id))
                return
            }
            // Theirs is older: replace ours with it and repoint our pins
            clipboard.applyRemoteDelete([twin.id])
            pinboards.replaceItem(twin.id, with: remote.id)
            meta.clips[twin.id] = nil
            dropped.append(SyncKey(.clip, twin.id))
            insert(entry, as: resolution.keep)
            if resolution.keep != remote { reupload.append(SyncKey(.clip, remote.id)) }
            return
        }

        insert(entry, as: remote)
    }

    private func insert(_ entry: RemoteChanges.Clip, as clip: SyncClip) {
        store(entry, for: clip.id)
        let item = makeItem(from: clip, existing: nil, hasImage: entry.imageData != nil, hasRTF: entry.richText != nil)
        clipboard.applyRemote(item)
        meta.clips[clip.id] = Meta.Clip(
            device: clip.device, createdAt: clip.createdAt, modifiedAt: clip.modifiedAt, contentHash: clip.contentHash)
    }

    /// Write downloaded image and rich-text bytes where the Mac app expects them.
    private func store(_ entry: RemoteChanges.Clip, for id: UUID) {
        if let image = entry.imageData { ImageStore.shared.save(data: image, for: id) }
        if let richText = entry.richText {
            RTFStore.shared.save(data: richText, for: id)
        }
    }
}
