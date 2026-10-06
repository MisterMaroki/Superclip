//
//  CloudRecordCoding.swift
//  Superclip (shared by the Mac and iPhone apps)
//
//  Converts the sync models to and from CloudKit records. Anything the user
//  typed or copied goes into encrypted fields; only what is needed for
//  ordering and merging is stored in the clear.
//

import CloudKit
import Foundation

enum CloudRecordCoding {
    enum Field {
        static let type = "type"
        static let content = "content"  // encrypted
        static let title = "title"  // encrypted
        static let createdAt = "createdAt"
        static let lastUsedAt = "lastUsedAt"
        static let modifiedAt = "modifiedAt"
        static let sourceApp = "sourceApp"
        static let sourceBundleID = "sourceBundleID"
        static let device = "device"
        static let imageWidth = "imageWidth"
        static let imageHeight = "imageHeight"
        static let contentHash = "contentHash"
        static let image = "image"  // asset
        static let imageOmitted = "imageOmitted"
        static let richText = "richText"  // encrypted
        static let name = "name"  // encrypted
        static let color = "color"
        static let position = "position"
        static let clipIDs = "clipIDs"
        static let trigger = "trigger"  // encrypted
        static let isEnabled = "isEnabled"
    }

    // MARK: Clips

    static func encode(_ clip: SyncClip, into record: CKRecord) {
        record[Field.type] = clip.type.rawValue
        record.encryptedValues[Field.content] = clip.content
        record.encryptedValues[Field.title] = clip.title
        record[Field.createdAt] = clip.createdAt
        record[Field.lastUsedAt] = clip.lastUsedAt
        record[Field.modifiedAt] = clip.modifiedAt
        record[Field.sourceApp] = clip.sourceApp
        record[Field.sourceBundleID] = clip.sourceBundleID
        record[Field.device] = clip.device
        record[Field.imageWidth] = clip.imageWidth
        record[Field.imageHeight] = clip.imageHeight
        record[Field.contentHash] = clip.contentHash
    }

    static func decodeClip(_ record: CKRecord) -> SyncClip? {
        guard let key = SyncKey(recordName: record.recordID.recordName), key.entity == .clip,
            let typeName = record[Field.type] as? String, let type = SyncClipType(rawValue: typeName),
            let content = record.encryptedValues[Field.content] as? String,
            let lastUsedAt = record[Field.lastUsedAt] as? Date
        else { return nil }
        return SyncClip(
            id: key.id,
            type: type,
            content: content,
            title: record.encryptedValues[Field.title] as? String,
            createdAt: record[Field.createdAt] as? Date ?? lastUsedAt,
            lastUsedAt: lastUsedAt,
            modifiedAt: record[Field.modifiedAt] as? Date ?? lastUsedAt,
            sourceApp: record[Field.sourceApp] as? String,
            sourceBundleID: record[Field.sourceBundleID] as? String,
            device: record[Field.device] as? String ?? "Another device",
            imageWidth: record[Field.imageWidth] as? Int,
            imageHeight: record[Field.imageHeight] as? Int,
            contentHash: record[Field.contentHash] as? String ?? SyncClip.hash(type: type, content: content)
        )
    }

    // MARK: Pinboards

    static func encode(_ pinboard: SyncPinboard, into record: CKRecord) {
        record.encryptedValues[Field.name] = pinboard.name
        record[Field.color] = pinboard.color
        record[Field.position] = pinboard.position
        record[Field.clipIDs] = pinboard.clipIDs.map(\.uuidString)
        record[Field.modifiedAt] = pinboard.modifiedAt
    }

    static func decodePinboard(_ record: CKRecord) -> SyncPinboard? {
        guard let key = SyncKey(recordName: record.recordID.recordName), key.entity == .pinboard,
            let name = record.encryptedValues[Field.name] as? String
        else { return nil }
        return SyncPinboard(
            id: key.id,
            name: name,
            color: record[Field.color] as? String ?? "red",
            position: record[Field.position] as? Int ?? 0,
            clipIDs: (record[Field.clipIDs] as? [String] ?? []).compactMap(UUID.init(uuidString:)),
            modifiedAt: record[Field.modifiedAt] as? Date ?? .distantPast
        )
    }

    // MARK: Snippets

    static func encode(_ snippet: SyncSnippet, into record: CKRecord) {
        record.encryptedValues[Field.name] = snippet.name
        record.encryptedValues[Field.trigger] = snippet.trigger
        record.encryptedValues[Field.content] = snippet.content
        record[Field.isEnabled] = snippet.isEnabled ? 1 : 0
        record[Field.modifiedAt] = snippet.modifiedAt
    }

    static func decodeSnippet(_ record: CKRecord) -> SyncSnippet? {
        guard let key = SyncKey(recordName: record.recordID.recordName), key.entity == .snippet,
            let content = record.encryptedValues[Field.content] as? String
        else { return nil }
        return SyncSnippet(
            id: key.id,
            name: record.encryptedValues[Field.name] as? String ?? "Untitled",
            trigger: record.encryptedValues[Field.trigger] as? String ?? "",
            content: content,
            isEnabled: (record[Field.isEnabled] as? Int ?? 1) != 0,
            modifiedAt: record[Field.modifiedAt] as? Date ?? .distantPast
        )
    }

    // MARK: System fields

    /// The part of a record CloudKit needs to accept an update to it (its
    /// identity and change tag), without any of our own fields.
    static func systemFields(of record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    static func record(fromSystemFields data: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        let record = CKRecord(coder: coder)
        coder.finishDecoding()
        return record
    }
}
