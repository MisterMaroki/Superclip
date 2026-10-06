//
//  CloudSyncEngine.swift
//  Superclip (shared by the Mac and iPhone apps)
//
//  Keeps the app's clips, pinboards and snippets in step with the user's
//  private iCloud database. This is the only code that talks to CloudKit.
//
//  CKSyncEngine does the scheduling, batching, retrying and push handling.
//  This type decides what to send, turns records into the sync models, and
//  hands incoming changes to the app's store, which merges them.
//

import CloudKit
import Combine
import Foundation

/// What the engine needs from an app. Both apps implement it over their own storage.
@MainActor
protocol CloudSyncStore: AnyObject {
    /// Current local version of a record, or nil if it no longer exists.
    func syncClip(_ id: UUID) -> SyncClip?
    func syncPinboard(_ id: UUID) -> SyncPinboard?
    func syncSnippet(_ id: UUID) -> SyncSnippet?
    func isPinned(_ clipID: UUID) -> Bool
    func imageData(forClip id: UUID) -> Data?
    func richTextData(forClip id: UUID) -> Data?
    /// Everything that should exist in iCloud, for the first upload.
    func allSyncKeys() -> [SyncKey]
    /// Merge changes that arrived from iCloud into local data.
    func apply(_ changes: RemoteChanges)
}

/// A batch of changes fetched from iCloud.
struct RemoteChanges {
    struct Clip {
        var clip: SyncClip
        /// Downloaded image bytes, when the record carried them.
        var imageData: Data?
        var richText: Data?
    }

    struct Pinboard {
        var pinboard: SyncPinboard
        /// The clip list as this device last synced it: the common ancestor
        /// for merging pins added or removed on both sides.
        var ancestorClipIDs: [UUID]?
    }

    var clips: [Clip] = []
    var pinboards: [Pinboard] = []
    var snippets: [SyncSnippet] = []
    var deleted: [SyncKey] = []

    var isEmpty: Bool { clips.isEmpty && pinboards.isEmpty && snippets.isEmpty && deleted.isEmpty }
}

@MainActor
final class CloudSyncEngine: NSObject, ObservableObject {

    enum Status: Equatable {
        case off
        /// Sync cannot run; the text says why, in words for the user.
        case unavailable(String)
        case syncing
        case upToDate(Date)
        case failed(String)

        var label: String {
            switch self {
            case .off: return "Off"
            case .unavailable(let reason): return reason
            case .syncing: return "Syncing\u{2026}"
            case .upToDate: return "Up to date"
            case .failed(let reason): return reason
            }
        }
    }

    static let containerIdentifier = "iCloud.com.omarmaroki.Superclip"
    static let zoneID = CKRecordZone.ID(zoneName: "Superclip", ownerName: CKCurrentUserDefaultName)

    @Published private(set) var status: Status = .off

    private weak var store: CloudSyncStore?
    private var engine: CKSyncEngine?
    private let directory: URL
    private var persisted = Persisted()
    private var hasExpiredThisLaunch = false

    /// What the engine remembers between launches, besides CloudKit's own state.
    private struct Persisted: Codable {
        var serialization: CKSyncEngine.State.Serialization?
        /// Record name -> system fields of the last version seen on the server.
        var systemFields: [String: Data] = [:]
        /// Pinboard record name -> clip IDs as last synced (merge ancestor).
        var pinboardBases: [String: [UUID]] = [:]
        /// Clip record name -> "last used" as last synced, for expiring
        /// records whose local copy has already been trimmed.
        var clipDates: [String: Date] = [:]
        /// Clips whose image has already been uploaded (not sent again).
        var uploadedImages: Set<String> = []
    }

    /// - Parameter directory: where to keep sync state (inside the app's own data folder).
    init(store: CloudSyncStore, directory: URL) {
        self.store = store
        self.directory = directory
        super.init()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    // MARK: Availability

    /// Whether this build is signed with the iCloud capability. Without it,
    /// touching CloudKit raises an exception, so every entry point checks first.
    static var isEntitled: Bool {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(
            task, "com.apple.developer.icloud-services" as CFString, nil)
        return (value as? [String])?.contains("CloudKit") ?? false
        #else
        // The iPhone project always carries the entitlement.
        return true
        #endif
    }

    // MARK: Lifecycle

    func start() {
        guard engine == nil else { return }
        guard Self.isEntitled else {
            status = .unavailable("This build isn\u{2019}t signed for iCloud")
            return
        }

        let container = CKContainer(identifier: Self.containerIdentifier)
        let isFirstRun = persisted.serialization == nil
        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: persisted.serialization,
            delegate: self)
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        status = .syncing

        if isFirstRun {
            enqueueEverything()
        }

        Task { [weak self] in
            let accountStatus = try? await container.accountStatus()
            guard let self else { return }
            switch accountStatus {
            case .available:
                break
            case .noAccount:
                self.status = .unavailable("Sign in to iCloud to sync")
            case .restricted:
                self.status = .unavailable("iCloud is restricted on this device")
            default:
                self.status = .unavailable("iCloud isn\u{2019}t available right now")
            }
        }
    }

    func stop() {
        engine = nil
        status = .off
    }

    /// Forget everything about the cloud copy. Local data is untouched. Used
    /// when sync is switched off, so switching it back on starts cleanly.
    func resetCloudState() {
        persisted = Persisted()
        save()
    }

    // MARK: Local changes

    /// Records that were added or changed locally.
    func noteChanged(_ keys: [SyncKey]) {
        guard let engine, !keys.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: keys.map { .saveRecord(recordID(for: $0)) })
    }

    /// Records the user deleted.
    func noteDeleted(_ keys: [SyncKey]) {
        guard let engine, !keys.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: keys.map { .deleteRecord(recordID(for: $0)) })
        for key in keys { forget(key.recordName) }
        save()
    }

    /// Ask for changes now rather than waiting for a push (app came to the front).
    func fetchNow() {
        guard let engine else { return }
        Task {
            try? await engine.fetchChanges()
        }
    }

    private func enqueueEverything() {
        guard let engine, let store else { return }
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        let keys = store.allSyncKeys().filter { key in
            guard key.entity == .clip, let clip = store.syncClip(key.id) else { return true }
            return !SyncPolicy.isExpired(lastUsedAt: clip.lastUsedAt, isPinned: store.isPinned(key.id))
        }
        engine.state.add(pendingRecordZoneChanges: keys.map { .saveRecord(recordID(for: $0)) })
    }

    private func recordID(for key: SyncKey) -> CKRecord.ID {
        CKRecord.ID(recordName: key.recordName, zoneID: Self.zoneID)
    }

    // MARK: Building records to send

    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let store, let key = SyncKey(recordName: recordID.recordName) else { return nil }
        let name = recordID.recordName
        let record =
            persisted.systemFields[name].flatMap(CloudRecordCoding.record(fromSystemFields:))
            ?? CKRecord(recordType: key.entity.recordType, recordID: recordID)

        switch key.entity {
        case .clip:
            guard let clip = store.syncClip(key.id),
                !SyncPolicy.isExpired(lastUsedAt: clip.lastUsedAt, isPinned: store.isPinned(key.id))
            else {
                // Gone or too old to sync: drop the pending upload
                engine?.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
            CloudRecordCoding.encode(clip, into: record)
            if clip.type == .image, !persisted.uploadedImages.contains(name) {
                attachImage(for: clip, to: record)
            }
            if let richText = store.richTextData(forClip: key.id), richText.count < 700_000 {
                record.encryptedValues[CloudRecordCoding.Field.richText] = richText
            } else {
                record.encryptedValues[CloudRecordCoding.Field.richText] = nil
            }
        case .pinboard:
            guard let pinboard = store.syncPinboard(key.id) else {
                engine?.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
            CloudRecordCoding.encode(pinboard, into: record)
        case .snippet:
            guard let snippet = store.syncSnippet(key.id) else {
                engine?.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
            CloudRecordCoding.encode(snippet, into: record)
        }
        return record
    }

    private var outbox: URL { directory.appendingPathComponent("outbox", isDirectory: true) }

    private func attachImage(for clip: SyncClip, to record: CKRecord) {
        guard let data = store?.imageData(forClip: clip.id) else { return }
        guard data.count <= SyncPolicy.maxImageBytes else {
            // Too large for iCloud: the other device shows the clip's details
            // and says the full image is on this one.
            record[CloudRecordCoding.Field.imageOmitted] = 1
            return
        }
        try? FileManager.default.createDirectory(at: outbox, withIntermediateDirectories: true)
        let file = outbox.appendingPathComponent(clip.id.uuidString)
        guard (try? data.write(to: file, options: .atomic)) != nil else { return }
        record[CloudRecordCoding.Field.image] = CKAsset(fileURL: file)
        record[CloudRecordCoding.Field.imageOmitted] = 0
    }

    // MARK: Handling what comes back

    private func process(_ event: CKSyncEngine.Event) {
        switch event {
        case .stateUpdate(let update):
            persisted.serialization = update.stateSerialization
            save()

        case .accountChange(let change):
            switch change.changeType {
            case .signIn:
                enqueueEverything()
                status = .syncing
            case .signOut:
                resetCloudState()
                status = .unavailable("Sign in to iCloud to sync")
            case .switchAccounts:
                // A different account: nothing we remember applies to it
                resetCloudState()
                enqueueEverything()
            @unknown default:
                break
            }

        case .fetchedDatabaseChanges(let changes):
            // The zone was removed (data deleted from iCloud settings, or an
            // encryption reset). Local data is still here: upload it again.
            if changes.deletions.contains(where: { $0.zoneID == Self.zoneID }) {
                persisted.systemFields = [:]
                persisted.pinboardBases = [:]
                persisted.clipDates = [:]
                persisted.uploadedImages = []
                save()
                enqueueEverything()
            }

        case .fetchedRecordZoneChanges(let changes):
            var remote = RemoteChanges()
            for modification in changes.modifications {
                collect(modification.record, into: &remote)
            }
            for deletion in changes.deletions {
                guard let key = SyncKey(recordName: deletion.recordID.recordName) else { continue }
                remote.deleted.append(key)
                forget(key.recordName)
            }
            deliver(remote)

        case .sentRecordZoneChanges(let sent):
            handleSent(sent)

        case .willFetchChanges, .willSendChanges:
            if case .unavailable = status {} else { status = .syncing }

        case .didFetchChanges:
            expireOldClipsOnce()
            markIdle()

        case .didSendChanges:
            try? FileManager.default.removeItem(at: outbox)
            markIdle()

        case .sentDatabaseChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break

        @unknown default:
            break
        }
    }

    private func markIdle() {
        switch status {
        case .unavailable, .failed, .off:
            break
        default:
            status = .upToDate(Date())
        }
    }

    /// Decode one fetched record into the batch, remembering its system fields.
    private func collect(_ record: CKRecord, into remote: inout RemoteChanges) {
        let name = record.recordID.recordName
        guard let key = SyncKey(recordName: name) else { return }
        persisted.systemFields[name] = CloudRecordCoding.systemFields(of: record)

        switch key.entity {
        case .clip:
            guard let clip = CloudRecordCoding.decodeClip(record) else { return }
            var entry = RemoteChanges.Clip(clip: clip)
            if let asset = record[CloudRecordCoding.Field.image] as? CKAsset, let url = asset.fileURL {
                entry.imageData = try? Data(contentsOf: url)
                persisted.uploadedImages.insert(name)
            }
            entry.richText = record.encryptedValues[CloudRecordCoding.Field.richText] as? Data
            persisted.clipDates[name] = clip.lastUsedAt
            remote.clips.append(entry)
        case .pinboard:
            guard let pinboard = CloudRecordCoding.decodePinboard(record) else { return }
            remote.pinboards.append(
                RemoteChanges.Pinboard(pinboard: pinboard, ancestorClipIDs: persisted.pinboardBases[name]))
        case .snippet:
            guard let snippet = CloudRecordCoding.decodeSnippet(record) else { return }
            remote.snippets.append(snippet)
        }
    }

    private func deliver(_ remote: RemoteChanges) {
        guard !remote.isEmpty else {
            save()
            return
        }
        store?.apply(remote)
        // What the store now holds for these pinboards is the new merge base
        for entry in remote.pinboards {
            let key = SyncKey(.pinboard, entry.pinboard.id)
            persisted.pinboardBases[key.recordName] = store?.syncPinboard(entry.pinboard.id)?.clipIDs
        }
        save()
    }

    private func handleSent(_ sent: CKSyncEngine.Event.SentRecordZoneChanges) {
        for record in sent.savedRecords {
            let name = record.recordID.recordName
            persisted.systemFields[name] = CloudRecordCoding.systemFields(of: record)
            guard let key = SyncKey(recordName: name) else { continue }
            switch key.entity {
            case .clip:
                if record[CloudRecordCoding.Field.image] != nil { persisted.uploadedImages.insert(name) }
                persisted.clipDates[name] = record[CloudRecordCoding.Field.lastUsedAt] as? Date
            case .pinboard:
                persisted.pinboardBases[name] = CloudRecordCoding.decodePinboard(record)?.clipIDs
            case .snippet:
                break
            }
        }

        var conflicts = RemoteChanges()
        var retry: [CKSyncEngine.PendingRecordZoneChange] = []

        for failure in sent.failedRecordSaves {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                // Someone else changed it first. Take their version in (the
                // store merges it with ours), then send the merged result.
                if let server = failure.error.serverRecord {
                    collect(server, into: &conflicts)
                    retry.append(.saveRecord(recordID))
                }
            case .zoneNotFound, .userDeletedZone:
                engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
                retry.append(.saveRecord(recordID))
            case .unknownItem:
                // The server no longer has it; save it as a new record
                persisted.systemFields[recordID.recordName] = nil
                retry.append(.saveRecord(recordID))
            case .quotaExceeded:
                status = .failed("iCloud storage is full")
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                .notAuthenticated, .operationCancelled, .requestRateLimited:
                break  // the engine retries these by itself
            default:
                print("[Sync] save failed for \(recordID.recordName): \(failure.error.localizedDescription)")
            }
        }

        for recordID in sent.deletedRecordIDs {
            forget(recordID.recordName)
        }

        deliver(conflicts)
        if !retry.isEmpty {
            engine?.state.add(pendingRecordZoneChanges: retry)
        }
        save()
    }

    /// Remove clips from iCloud that have aged past the retention window. The
    /// local copies stay; devices treat this kind of removal as expiry, not
    /// as the user deleting something.
    private func expireOldClipsOnce() {
        guard !hasExpiredThisLaunch, let engine, let store else { return }
        hasExpiredThisLaunch = true
        var expired: [CKSyncEngine.PendingRecordZoneChange] = []
        for (name, lastSynced) in persisted.clipDates {
            guard let key = SyncKey(recordName: name) else { continue }
            let lastUsed = store.syncClip(key.id)?.lastUsedAt ?? lastSynced
            if SyncPolicy.isExpired(lastUsedAt: lastUsed, isPinned: store.isPinned(key.id)) {
                expired.append(.deleteRecord(recordID(for: key)))
            }
        }
        guard !expired.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: expired)
    }

    private func forget(_ recordName: String) {
        persisted.systemFields[recordName] = nil
        persisted.pinboardBases[recordName] = nil
        persisted.clipDates[recordName] = nil
        persisted.uploadedImages.remove(recordName)
    }

    // MARK: Persistence

    private var stateURL: URL { directory.appendingPathComponent("sync-state.json") }

    private func load() {
        guard let data = try? Data(contentsOf: stateURL),
            let decoded = try? JSONDecoder().decode(Persisted.self, from: data)
        else { return }
        persisted = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }
}

// MARK: - CKSyncEngineDelegate

extension CloudSyncEngine: CKSyncEngineDelegate {
    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await process(event)
    }

    nonisolated func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            await self.record(for: recordID)
        }
    }
}
