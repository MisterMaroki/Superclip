//
//  SyncMerge.swift
//  Superclip (shared by the Mac and iPhone apps)
//
//  The rules that make two devices arrive at the same result. Everything here
//  is a pure function of its inputs, so both devices can apply a rule
//  independently and agree, and so the rules can be tested without iCloud.
//

import Foundation

enum SyncMerge {

    // MARK: Clips

    /// Combine the local and incoming versions of the same clip (same ID).
    /// The later edit wins the content; "last used" only ever moves forward.
    static func merge(local: SyncClip, remote: SyncClip) -> SyncClip {
        var result = remote.modifiedAt >= local.modifiedAt ? remote : local
        result.lastUsedAt = max(local.lastUsedAt, remote.lastUsedAt)
        result.createdAt = min(local.createdAt, remote.createdAt)
        return result
    }

    /// Two clips with different IDs but the same content, captured on
    /// different devices (typically one copy relayed by Universal Clipboard
    /// and saved on both). Returns which to keep and which to drop.
    ///
    /// The choice depends only on the two clips, never on which device is
    /// asking, so every device picks the same survivor. Returns nil when they
    /// are not duplicates in this sense.
    static func resolveDuplicate(_ a: SyncClip, _ b: SyncClip) -> (keep: SyncClip, drop: SyncClip)? {
        guard a.id != b.id, a.contentHash == b.contentHash, a.type == b.type, a.device != b.device
        else { return nil }
        let aFirst: Bool
        if a.createdAt != b.createdAt {
            aFirst = a.createdAt < b.createdAt
        } else {
            aFirst = a.id.uuidString < b.id.uuidString
        }
        var keep = aFirst ? a : b
        let drop = aFirst ? b : a
        keep.lastUsedAt = max(a.lastUsedAt, b.lastUsedAt)
        return (keep, drop)
    }

    // MARK: Pinboards

    /// Combine two versions of a pinboard. Name, colour and position follow
    /// the later change. The clip list is merged item by item against the
    /// common ancestor, so pinning A on one device and B on another keeps
    /// both, and an unpin on either device sticks.
    static func merge(local: SyncPinboard, remote: SyncPinboard, ancestor: SyncPinboard?) -> SyncPinboard {
        var result = remote.modifiedAt >= local.modifiedAt ? remote : local
        result.clipIDs = mergeLists(local: local.clipIDs, remote: remote.clipIDs, ancestor: ancestor?.clipIDs)
        result.modifiedAt = max(local.modifiedAt, remote.modifiedAt)
        return result
    }

    /// Three-way merge of an ordered ID list. Without an ancestor nothing can
    /// be told apart as "removed", so the result is the union.
    static func mergeLists(local: [UUID], remote: [UUID], ancestor: [UUID]?) -> [UUID] {
        let localSet = Set(local), remoteSet = Set(remote)
        let base = Set(ancestor ?? [])
        let removed = ancestor == nil ? [] : base.subtracting(localSet).union(base.subtracting(remoteSet))

        var seen = Set<UUID>()
        var result: [UUID] = []
        // Remote order first (it is what the other devices already show),
        // then anything only this device has
        for id in remote + local where !removed.contains(id) && seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }

    /// Point pins at the surviving clip after a duplicate was dropped.
    static func remap(_ ids: [UUID], replacing dropped: UUID, with kept: UUID) -> [UUID] {
        var seen = Set<UUID>()
        return ids.map { $0 == dropped ? kept : $0 }.filter { seen.insert($0).inserted }
    }

    // MARK: Snippets

    static func merge(local: SyncSnippet, remote: SyncSnippet) -> SyncSnippet {
        remote.modifiedAt >= local.modifiedAt ? remote : local
    }
}

/// Finds what changed between two looks at the local data, so the apps don't
/// have to report every mutation by hand. Each record is reduced to a
/// signature; a new or different signature means "upload this".
struct SyncChangeTracker {
    private var signatures: [SyncKey: Int] = [:]

    /// Compare against the last call. Returns records that are new or changed.
    /// Records that disappeared are simply forgotten: disappearing is not the
    /// same as being deleted (history trimming removes clips locally without
    /// deleting them everywhere), so deletions are reported explicitly.
    mutating func changes(in current: [SyncKey: Int]) -> [SyncKey] {
        var changed: [SyncKey] = []
        for (key, signature) in current where signatures[key] != signature {
            changed.append(key)
        }
        signatures = current
        return changed
    }

    /// Record the current state without reporting anything, after applying
    /// changes that came from the cloud (they must not be sent straight back).
    mutating func acknowledge(_ current: [SyncKey: Int]) {
        signatures = current
    }

    var isEmpty: Bool { signatures.isEmpty }
}

extension SyncClip {
    /// Changes whenever something that syncs changes.
    var signature: Int {
        var hasher = Hasher()
        hasher.combine(content)
        hasher.combine(title)
        hasher.combine(lastUsedAt)
        hasher.combine(modifiedAt)
        return hasher.finalize()
    }
}

extension SyncPinboard {
    var signature: Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(color)
        hasher.combine(position)
        hasher.combine(clipIDs)
        return hasher.finalize()
    }
}

extension SyncSnippet {
    var signature: Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(trigger)
        hasher.combine(content)
        hasher.combine(isEnabled)
        return hasher.finalize()
    }
}
