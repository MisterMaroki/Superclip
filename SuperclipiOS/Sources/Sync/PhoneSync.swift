//
//  PhoneSync.swift
//  Superclip for iPhone
//
//  Connects the iPhone's store to the shared sync engine: notices local
//  changes and queues them, and merges what arrives from iCloud.
//

import Combine
import Foundation
import UIKit

@MainActor
final class PhoneSync: ObservableObject {
    static let enabledKey = "syncEnabled"

    private let store: ClipStore
    private var engine: CloudSyncEngine?
    private var tracker = SyncChangeTracker()
    private var isApplyingRemote = false
    private var cancellables = Set<AnyCancellable>()
    private var changeSubscription: AnyCancellable?

    private let directory: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Superclip/sync", isDirectory: true)
    }()

    /// On unless the user turned it off: on the iPhone, sync is the point.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            objectWillChange.send()
            if newValue { start() } else { stop() }
        }
    }

    init(store: ClipStore) {
        self.store = store
        store.onUserDeleted = { [weak self] keys in self?.userDeleted(keys) }
    }

    // MARK: Lifecycle

    func start() {
        guard isEnabled, engine == nil else { return }
        let engine = CloudSyncEngine(store: self, directory: directory)
        self.engine = engine
        engine.$status
            .sink { [weak self] status in self?.reflect(status) }
            .store(in: &cancellables)

        tracker.acknowledge(signatures())
        engine.start()

        changeSubscription = store.objectWillChange
            .debounce(for: .milliseconds(800), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.pushLocalChanges() }
    }

    func stop() {
        changeSubscription = nil
        engine?.stop()
        engine?.resetCloudState()
        engine = nil
        store.syncState = .localOnly
        store.syncDetail = "Sync is off. Clips you save stay on this iPhone."
    }

    /// The app came to the front: ask for changes now, and send any of ours.
    func refresh() {
        pushLocalChanges()
        engine?.fetchNow()
    }

    private func reflect(_ status: CloudSyncEngine.Status) {
        switch status {
        case .off:
            store.syncState = .localOnly
            store.syncDetail = "Sync is off. Clips you save stay on this iPhone."
        case .unavailable(let reason):
            store.syncState = .localOnly
            store.syncDetail = reason + ". Until then, clips stay on this iPhone."
        case .failed(let reason):
            store.syncState = .localOnly
            store.syncDetail = reason + "."
        case .syncing:
            store.syncState = .syncing
            store.syncDetail = "Checking iCloud for changes."
        case .upToDate(let date):
            store.syncState = .upToDate(date)
            store.syncDetail = "Clips, pinboards and snippets are shared with Superclip on your Mac through your iCloud."
        }
    }

    // MARK: Local changes -> cloud

    private func pushLocalChanges() {
        guard let engine, !isApplyingRemote else { return }
        let changed = tracker.changes(in: signatures())
        engine.noteChanged(changed)
    }

    private func userDeleted(_ keys: [SyncKey]) {
        guard engine != nil, !isApplyingRemote else { return }
        // Wait out the Undo toast: a delete that is undone never leaves the phone
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, let engine = self.engine else { return }
            let stillGone = keys.filter { key in
                switch key.entity {
                case .clip: return !self.store.clips.contains { $0.id == key.id }
                case .pinboard: return !self.store.pinboards.contains { $0.id == key.id }
                case .snippet: return !self.store.snippets.contains { $0.id == key.id }
                }
            }
            engine.noteDeleted(stillGone)
        }
    }

    private func signatures() -> [SyncKey: Int] {
        var result: [SyncKey: Int] = [:]
        for clip in store.clips {
            var hasher = Hasher()
            hasher.combine(clip.content)
            hasher.combine(clip.title)
            hasher.combine(clip.lastUsedAt)
            result[SyncKey(.clip, clip.id)] = hasher.finalize()
        }
        for (index, board) in store.pinboards.enumerated() {
            var hasher = Hasher()
            hasher.combine(board.name)
            hasher.combine(board.tint.rawValue)
            hasher.combine(board.clipIDs)
            hasher.combine(index)
            result[SyncKey(.pinboard, board.id)] = hasher.finalize()
        }
        for snippet in store.snippets {
            var hasher = Hasher()
            hasher.combine(snippet.name)
            hasher.combine(snippet.trigger)
            hasher.combine(snippet.content)
            result[SyncKey(.snippet, snippet.id)] = hasher.finalize()
        }
        return result
    }

    // MARK: Model conversion

    private func makeSyncClip(_ clip: Clip) -> SyncClip {
        let type: SyncClipType
        switch clip.kind {
        case .image: type = .image
        case .link: type = .link
        case .text, .color, .code: type = .text
        }
        return SyncClip(
            id: clip.id, type: type, content: clip.content, title: clip.title,
            createdAt: clip.createdAt, lastUsedAt: clip.lastUsedAt,
            modifiedAt: clip.modifiedAt ?? clip.createdAt, sourceApp: clip.sourceApp,
            sourceBundleID: nil, device: clip.device, imageWidth: clip.imageWidth,
            imageHeight: clip.imageHeight,
            contentHash: type == .image
                ? "image-" + clip.id.uuidString : SyncClip.hash(type: type, content: clip.content))
    }

    private func makeClip(_ sync: SyncClip, existing: Clip?) -> Clip {
        let kind: ClipKind
        switch sync.type {
        case .image: kind = .image
        case .link: kind = .link
        case .text: kind = ClipClassifier.kind(of: sync.content)
        }
        return Clip(
            id: sync.id, kind: kind, content: sync.content, title: sync.title,
            imageFile: existing?.imageFile, imageWidth: sync.imageWidth, imageHeight: sync.imageHeight,
            createdAt: sync.createdAt, lastUsedAt: sync.lastUsedAt, modifiedAt: sync.modifiedAt,
            sourceApp: sync.sourceApp, device: sync.device)
    }
}

// MARK: - CloudSyncStore

extension PhoneSync: CloudSyncStore {

    func syncClip(_ id: UUID) -> SyncClip? {
        store.clips.first(where: { $0.id == id }).map(makeSyncClip)
    }

    func syncPinboard(_ id: UUID) -> SyncPinboard? {
        guard let index = store.pinboards.firstIndex(where: { $0.id == id }) else { return nil }
        let board = store.pinboards[index]
        return SyncPinboard(
            id: board.id, name: board.name, color: board.tint.rawValue, position: index,
            clipIDs: board.clipIDs, modifiedAt: board.modifiedAt ?? .distantPast)
    }

    func syncSnippet(_ id: UUID) -> SyncSnippet? {
        guard let snippet = store.snippets.first(where: { $0.id == id }) else { return nil }
        return SyncSnippet(
            id: snippet.id, name: snippet.name, trigger: snippet.trigger, content: snippet.content,
            isEnabled: snippet.isEnabled ?? true, modifiedAt: snippet.modifiedAt ?? .distantPast)
    }

    func isPinned(_ clipID: UUID) -> Bool {
        store.pinboards.contains { $0.clipIDs.contains(clipID) }
    }

    func imageData(forClip id: UUID) -> Data? {
        store.clips.first(where: { $0.id == id }).flatMap { store.imageData(for: $0) }
    }

    func richTextData(forClip id: UUID) -> Data? { nil }

    func allSyncKeys() -> [SyncKey] {
        store.clips.map { SyncKey(.clip, $0.id) } + store.pinboards.map { SyncKey(.pinboard, $0.id) }
            + store.snippets.map { SyncKey(.snippet, $0.id) }
    }

    func apply(_ changes: RemoteChanges) {
        isApplyingRemote = true
        var reupload: [SyncKey] = []
        var dropped: [SyncKey] = []

        for entry in changes.clips {
            let remote = entry.clip
            if let existing = store.clips.first(where: { $0.id == remote.id }) {
                let merged = SyncMerge.merge(local: makeSyncClip(existing), remote: remote)
                store.syncUpsert(makeClip(merged, existing: existing), imageData: entry.imageData)
                if merged != remote { reupload.append(SyncKey(.clip, merged.id)) }
                continue
            }
            // The same content already saved here under another ID
            if remote.type != .image,
                let twin = store.clips.first(where: { $0.kind != .image && $0.content == remote.content }),
                let resolution = SyncMerge.resolveDuplicate(makeSyncClip(twin), remote)
            {
                if resolution.keep.id == twin.id {
                    store.syncUpsert(makeClip(resolution.keep, existing: twin), imageData: nil)
                    dropped.append(SyncKey(.clip, remote.id))
                    reupload.append(SyncKey(.clip, twin.id))
                } else {
                    store.syncReplaceClip(twin.id, with: remote.id)
                    store.syncRemoveClips([twin.id])
                    store.syncUpsert(makeClip(resolution.keep, existing: nil), imageData: entry.imageData)
                    dropped.append(SyncKey(.clip, twin.id))
                    if resolution.keep != remote { reupload.append(SyncKey(.clip, remote.id)) }
                }
                continue
            }
            store.syncUpsert(makeClip(remote, existing: nil), imageData: entry.imageData)
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
            store.syncUpsert(
                Pinboard(
                    id: merged.id, name: merged.name, tint: PinTint(rawValue: merged.color) ?? .red,
                    clipIDs: merged.clipIDs, modifiedAt: merged.modifiedAt),
                position: merged.position)
            if merged != remote { reupload.append(SyncKey(.pinboard, merged.id)) }
        }

        for remote in changes.snippets {
            var merged = remote
            if let local = syncSnippet(remote.id) { merged = SyncMerge.merge(local: local, remote: remote) }
            store.syncUpsert(
                Snippet(
                    id: merged.id, name: merged.name, trigger: merged.trigger, content: merged.content,
                    isEnabled: merged.isEnabled, modifiedAt: merged.modifiedAt))
            if merged != remote { reupload.append(SyncKey(.snippet, merged.id)) }
        }

        var deletedClips = Set<UUID>()
        for key in changes.deleted {
            switch key.entity {
            case .clip:
                // Aged out of iCloud is not the same as deleted by the user
                if let local = store.clips.first(where: { $0.id == key.id }),
                    SyncPolicy.isExpired(lastUsedAt: local.lastUsedAt, isPinned: isPinned(key.id))
                {
                    continue
                }
                deletedClips.insert(key.id)
            case .pinboard:
                store.syncRemovePinboard(key.id)
            case .snippet:
                store.syncRemoveSnippet(key.id)
            }
        }
        store.syncRemoveClips(deletedClips)

        tracker.acknowledge(signatures())
        isApplyingRemote = false
        engine?.noteChanged(reupload)
        engine?.noteDeleted(dropped)
    }
}
