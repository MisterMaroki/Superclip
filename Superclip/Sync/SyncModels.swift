//
//  SyncModels.swift
//  Superclip (shared by the Mac and iPhone apps)
//
//  What travels between devices. These types are deliberately plain: no
//  AppKit, no UIKit, nothing about how either app stores its data. Each app
//  converts its own model to and from them.
//

import CryptoKit
import Foundation

/// What a synced clip fundamentally is. Finer distinctions (colour, code) are
/// derived from the text on each device and are not synced.
enum SyncClipType: String, Codable {
    case text
    case link
    case image
}

struct SyncClip: Equatable, Identifiable {
    var id: UUID
    var type: SyncClipType
    /// The text, the URL, or for images a short description such as "1200x750".
    var content: String
    /// Page title for links.
    var title: String?
    /// When the clip was first copied, anywhere.
    var createdAt: Date
    /// When it was last copied or pasted. Orders the history.
    var lastUsedAt: Date
    /// When its content was last edited. Decides which edit wins.
    var modifiedAt: Date
    var sourceApp: String?
    var sourceBundleID: String?
    /// Name of the device it was first copied on.
    var device: String
    var imageWidth: Int?
    var imageHeight: Int?
    /// Identifies the content, for spotting the same clip captured on two devices.
    var contentHash: String

    /// Hash of a text or link clip.
    static func hash(type: SyncClipType, content: String) -> String {
        hash(of: Data((type.rawValue + "\u{1F}" + content).utf8))
    }

    /// Hash of an image clip's bytes.
    static func hash(imageData: Data) -> String {
        hash(of: imageData)
    }

    private static func hash(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct SyncPinboard: Equatable, Identifiable {
    var id: UUID
    var name: String
    /// Colour name; both apps use the same eight ("red", "orange", ...).
    var color: String
    /// Order among the pinboards.
    var position: Int
    var clipIDs: [UUID]
    var modifiedAt: Date
}

struct SyncSnippet: Equatable, Identifiable {
    var id: UUID
    var name: String
    var trigger: String
    var content: String
    var isEnabled: Bool
    var modifiedAt: Date
}

/// The three kinds of record, and how their IDs are written in the cloud.
enum SyncEntity: String, CaseIterable {
    case clip
    case pinboard
    case snippet

    /// CloudKit record type.
    var recordType: String {
        switch self {
        case .clip: return "Clip"
        case .pinboard: return "Pinboard"
        case .snippet: return "Snippet"
        }
    }
}

/// One record's identity: which kind, and which UUID.
struct SyncKey: Hashable {
    let entity: SyncEntity
    let id: UUID

    /// "clip.<uuid>": the cloud record name. The prefix lets a record ID alone
    /// say which kind of record it is.
    var recordName: String { "\(entity.rawValue).\(id.uuidString)" }

    init(_ entity: SyncEntity, _ id: UUID) {
        self.entity = entity
        self.id = id
    }

    init?(recordName: String) {
        let parts = recordName.split(separator: ".", maxSplits: 1)
        guard parts.count == 2, let entity = SyncEntity(rawValue: String(parts[0])),
            let id = UUID(uuidString: String(parts[1]))
        else { return nil }
        self.entity = entity
        self.id = id
    }
}

/// Rules about what is worth keeping in iCloud.
enum SyncPolicy {
    /// Unpinned clips not used for this long leave iCloud (they stay on the
    /// device that has them). Without a limit, a Mac set to unlimited history
    /// would grow the user's iCloud usage forever.
    static let retention: TimeInterval = 30 * 24 * 60 * 60

    /// Images larger than this sync as metadata only.
    static let maxImageBytes = 10 * 1024 * 1024

    static func isExpired(lastUsedAt: Date, isPinned: Bool, now: Date = Date()) -> Bool {
        !isPinned && now.timeIntervalSince(lastUsedAt) > retention
    }
}
