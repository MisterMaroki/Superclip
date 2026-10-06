//
//  ClipboardItem.swift
//  Superclip
//

import Foundation
import AppKit
import ImageIO

struct SourceApp: Equatable {
    let bundleIdentifier: String?
    let name: String

    /// Shared icon cache keyed by bundle identifier — avoids duplicating the same
    /// NSImage across hundreds of clipboard items from the same app.
    private static let iconCache = NSCache<NSString, NSImage>()

    /// The icon is resolved lazily from the cache so that each unique bundle ID
    /// stores only one copy in memory.
    var icon: NSImage? {
        guard let bid = bundleIdentifier else { return nil }
        let key = bid as NSString
        if let cached = Self.iconCache.object(forKey: key) {
            return cached
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            let img = NSWorkspace.shared.icon(forFile: appURL.path)
            Self.iconCache.setObject(img, forKey: key)
            return img
        }
        return nil
    }

    init(bundleIdentifier: String?, name: String, icon: NSImage?) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        // Pre-populate the cache when an icon is provided directly (e.g. from the running app)
        if let icon = icon, let bid = bundleIdentifier {
            Self.iconCache.setObject(icon, forKey: bid as NSString)
        }
    }
    
    // Get color based on app (you could expand this with more app-specific colors)
    var accentColor: Color {
        guard let bundleId = bundleIdentifier?.lowercased() else {
            return Color(nsColor: .systemGray)
        }
        
        // App-specific colors
        if bundleId.contains("xcode") {
            return Color(nsColor: .systemBlue)
        } else if bundleId.contains("safari") {
            return Color(nsColor: .systemBlue)
        } else if bundleId.contains("chrome") {
            return Color(red: 0.98, green: 0.75, blue: 0.18)
        } else if bundleId.contains("slack") {
            return Color(red: 0.38, green: 0.15, blue: 0.47)
        } else if bundleId.contains("discord") {
            return Color(red: 0.34, green: 0.40, blue: 0.95)
        } else if bundleId.contains("terminal") {
            return Color(nsColor: .systemGreen)
        } else if bundleId.contains("finder") {
            return Color(nsColor: .systemBlue)
        } else if bundleId.contains("notes") {
            return Color(nsColor: .systemYellow)
        } else if bundleId.contains("mail") {
            return Color(nsColor: .systemBlue)
        } else if bundleId.contains("messages") {
            return Color(nsColor: .systemGreen)
        } else if bundleId.contains("vscode") || bundleId.contains("visual-studio-code") {
            return Color(red: 0.0, green: 0.47, blue: 0.83)
        } else if bundleId.contains("cursor") {
            return Color(red: 0.0, green: 0.47, blue: 0.83)
        } else if bundleId.contains("figma") {
            return Color(red: 0.64, green: 0.32, blue: 1.0)
        } else if bundleId.contains("notion") {
            return Color(nsColor: .labelColor)
        } else if bundleId.contains("spotify") {
            return Color(red: 0.11, green: 0.73, blue: 0.33)
        } else if bundleId.contains("telegram") {
            return Color(red: 0.16, green: 0.63, blue: 0.89)
        } else if bundleId.contains("whatsapp") {
            return Color(red: 0.15, green: 0.68, blue: 0.38)
        }
        
        // Generate consistent color from bundle identifier
        let hash = abs(bundleId.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
}

import SwiftUI

// Link metadata for URL previews.
// Image/icon data is stored on disk (via LinkImageStore) and loaded lazily —
// only the lightweight title/url/flags are kept in memory.
class LinkMetadata: NSObject {
    let title: String?
    let url: URL
    /// Whether an image file exists on disk for this metadata.
    let hasImage: Bool
    /// Whether an icon file exists on disk for this metadata.
    let hasIcon: Bool

    /// In-memory image cache shared across all LinkMetadata instances.
    private static let imageCache: NSCache<NSURL, NSImage> = {
        let c = NSCache<NSURL, NSImage>()
        c.countLimit = 60
        c.totalCostLimit = 48 * 1024 * 1024  // 48 MB
        return c
    }()
    private static let iconCache: NSCache<NSURL, NSImage> = {
        let c = NSCache<NSURL, NSImage>()
        c.countLimit = 30
        c.totalCostLimit = 5 * 1024 * 1024   // 5 MB
        return c
    }()

    init(title: String?, url: URL, hasImage: Bool = false, hasIcon: Bool = false) {
        self.title = title
        self.url = url
        self.hasImage = hasImage
        self.hasIcon = hasIcon
        super.init()
    }

    /// Convenience initializer that persists raw image/icon data to disk.
    convenience init(title: String?, url: URL, imageData: Data?, iconData: Data?) {
        let hasImg = imageData != nil
        let hasIcn = iconData != nil
        self.init(title: title, url: url, hasImage: hasImg, hasIcon: hasIcn)
        if let data = imageData { LinkImageStore.shared.saveImage(data, for: url) }
        if let data = iconData  { LinkImageStore.shared.saveIcon(data, for: url) }
    }

    var image: NSImage? {
        guard hasImage else { return nil }
        let key = url as NSURL
        if let cached = Self.imageCache.object(forKey: key) { return cached }
        guard let data = LinkImageStore.shared.loadImage(for: url),
              let img = NSImage(data: data) else { return nil }
        // Cost by decoded size: file size says little about memory use
        Self.imageCache.setObject(img, forKey: key, cost: Int(img.size.width * img.size.height * 4))
        return img
    }

    var icon: NSImage? {
        guard hasIcon else { return nil }
        let key = url as NSURL
        if let cached = Self.iconCache.object(forKey: key) { return cached }
        guard let data = LinkImageStore.shared.loadIcon(for: url),
              let img = NSImage(data: data) else { return nil }
        Self.iconCache.setObject(img, forKey: key, cost: data.count)
        return img
    }

    var displayURL: String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = nil
        var display = components?.string ?? url.absoluteString
        if display.hasPrefix("//") {
            display = String(display.dropFirst(2))
        }
        if display.hasSuffix("/") {
            display = String(display.dropLast())
        }
        return display
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? LinkMetadata else { return false }
        return url == other.url && title == other.title
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(url)
        hasher.combine(title)
        return hasher.finalize()
    }
}

// MARK: - Link Image Store

/// On-disk storage for link metadata images and icons.
/// Files are stored in ~/Library/Application Support/Superclip/link-images/
class LinkImageStore {
    static let shared = LinkImageStore()

    private let imageDir: URL
    private let iconDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base = appSupport.appendingPathComponent("Superclip/link-images", isDirectory: true)
        imageDir = base.appendingPathComponent("images", isDirectory: true)
        iconDir = base.appendingPathComponent("icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: iconDir, withIntermediateDirectories: true)
    }

    func saveImage(_ data: Data, for url: URL) {
        try? data.write(to: imageFile(for: url), options: .atomic)
    }

    func saveIcon(_ data: Data, for url: URL) {
        try? data.write(to: iconFile(for: url), options: .atomic)
    }

    func loadImage(for url: URL) -> Data? {
        try? Data(contentsOf: imageFile(for: url))
    }

    func loadIcon(for url: URL) -> Data? {
        try? Data(contentsOf: iconFile(for: url))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: imageDir)
        try? FileManager.default.removeItem(at: iconDir)
        try? FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: iconDir, withIntermediateDirectories: true)
    }

    /// Remove preview images whose link is no longer in history. Until now
    /// nothing pruned this folder, so it only ever grew. Files newer than five
    /// minutes are left alone (a fetch may have just written them).
    func cleanupOrphans(keeping urls: [URL]) {
        let valid = Set(urls.map { safeFilename(for: $0) + ".dat" })
        let cutoff = Date().addingTimeInterval(-300)
        for dir in [imageDir, iconDir] {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for file in files where !valid.contains(file.lastPathComponent) {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                if modified < cutoff {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - Private

    private func safeFilename(for url: URL) -> String {
        // SHA-like short hash from the URL string to avoid filesystem-unsafe characters
        let str = url.absoluteString
        var hash: UInt64 = 5381
        for byte in str.utf8 { hash = hash &* 33 &+ UInt64(byte) }
        return String(hash, radix: 16)
    }

    private func imageFile(for url: URL) -> URL {
        imageDir.appendingPathComponent(safeFilename(for: url) + ".dat")
    }

    private func iconFile(for url: URL) -> URL {
        iconDir.appendingPathComponent(safeFilename(for: url) + ".dat")
    }
}

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipboardType
    var imageData: Data?
    let hasImage: Bool
    /// Stable content hash of the image bytes, computed once at capture time.
    /// Survives `imageData` being released to disk and app relaunches, so image
    /// deduplication keeps working (Data.hashValue is per-process randomized).
    let imageHash: String?
    let fileURLs: [URL]?
    let sourceApp: SourceApp?
    var linkMetadata: LinkMetadata?
    let hasRTF: Bool  // Whether RTF data exists on disk
    var detectedTags: Set<ContentTag>  // Auto-detected content sub-categories

    enum ClipboardType: String, Codable {
        case text
        case image
        case file
        case url
    }

    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), type: ClipboardType = .text, imageData: Data? = nil, hasImage: Bool? = nil, imageHash: String? = nil, fileURLs: [URL]? = nil, sourceApp: SourceApp? = nil, linkMetadata: LinkMetadata? = nil, rtfData: Data? = nil, hasRTF: Bool? = nil, detectedTags: Set<ContentTag> = []) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.type = type
        self.imageData = imageData
        self.hasImage = hasImage ?? (imageData != nil)
        self.imageHash = imageHash ?? imageData.map(Self.stableHash(of:))
        self.fileURLs = fileURLs
        self.sourceApp = sourceApp
        self.linkMetadata = linkMetadata
        self.hasRTF = hasRTF ?? (rtfData != nil)
        self.detectedTags = detectedTags
        // Persist RTF data to disk immediately, then release from memory
        if let rtfData = rtfData {
            RTFStore.shared.save(data: rtfData, for: id)
        }
    }

    /// RTF data loaded on demand from disk. Not held in memory.
    var rtfData: Data? {
        guard hasRTF else { return nil }
        return RTFStore.shared.loadData(for: id)
    }

    // Get attributed string from RTF data (memoized in RTFStore — this is
    // read from SwiftUI view bodies on every evaluation)
    var attributedString: NSAttributedString? {
        guard hasRTF else { return nil }
        return RTFStore.shared.attributedString(for: id)
    }

    // Check if item has rich text formatting
    var hasRichText: Bool {
        hasRTF
    }
    
    // Type label for display
    var typeLabel: String {
        switch type {
        case .text:
            return "Text"
        case .image:
            // Check file extension from content or image format
            return "Image"
        case .file:
            if let urls = fileURLs, urls.count == 1, let url = urls.first {
                let ext = url.pathExtension.lowercased()
                switch ext {
                case "jpg", "jpeg":
                    return "JPG"
                case "png":
                    return "PNG"
                case "gif":
                    return "GIF"
                case "mp4", "mov", "avi", "mkv", "webm":
                    return "Video"
                case "mp3", "wav", "m4a", "aac":
                    return "Audio"
                case "pdf":
                    return "PDF"
                default:
                    // Folders and extension-less files would otherwise get an empty label
                    if ext.isEmpty { return url.hasDirectoryPath ? "Folder" : "File" }
                    return ext.uppercased()
                }
            }
            return "File"
        case .url:
            return "Link"
        }
    }
    
    var preview: String {
        switch type {
        case .image:
            return "Image"
        case .file:
            if let urls = fileURLs {
                if urls.count == 1 {
                    return urls[0].lastPathComponent
                } else {
                    return "\(urls.count) files"
                }
            }
            return "File"
        case .url:
            return content
        default:
            if content.count > 100 {
                return String(content.prefix(100)) + "..."
            }
            return content
        }
    }
    
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var timeAgo: String {
        let now = Date()
        // The formatter renders a just-copied item as "in 0 sec" / "0 sec ago"
        if now.timeIntervalSince(timestamp) < 5 { return "Just now" }
        return Self.relativeFormatter.localizedString(for: timestamp, relativeTo: now)
    }
    
    /// Full-resolution image cache — only for active preview/paste. Kept tiny.
    private static let fullImageCache: NSCache<NSUUID, NSImage> = {
        let cache = NSCache<NSUUID, NSImage>()
        cache.countLimit = 3
        cache.totalCostLimit = 50 * 1024 * 1024  // 50 MB
        return cache
    }()

    /// Thumbnail cache for card display — small images, modest count.
    private static let thumbnailCache: NSCache<NSUUID, NSImage> = {
        let cache = NSCache<NSUUID, NSImage>()
        // A thumbnail is about half a megabyte decoded. The old limits (30
        // entries / 20 MB) held roughly one screenful, so scrolling back
        // through image clips re-read and re-decoded every one.
        cache.countLimit = 200
        cache.totalCostLimit = 96 * 1024 * 1024  // 96 MB
        return cache
    }()

    /// The thumbnail if it is already in memory. Never touches the disk, so
    /// it is safe to read from a view body.
    var cachedThumbnail: NSImage? {
        Self.thumbnailCache.object(forKey: id as NSUUID)
    }

    /// Produce the thumbnail off the main thread and deliver it on the main
    /// thread. Reading and decoding the original image inside a view body
    /// blocked scrolling for tens of milliseconds per image card.
    func loadThumbnail(completion: @escaping (NSImage?) -> Void) {
        if let cached = cachedThumbnail {
            completion(cached)
            return
        }
        let item = self
        DispatchQueue.global(qos: .userInitiated).async {
            let thumb = item.thumbnail
            DispatchQueue.main.async {
                completion(thumb)
            }
        }
    }

    /// Full-resolution image — loaded on demand from memory or disk.
    /// Used for preview, paste, share, drag-and-drop. Evicts aggressively.
    var nsImage: NSImage? {
        let key = id as NSUUID
        if let cached = Self.fullImageCache.object(forKey: key) {
            return cached
        }
        let data = imageData ?? ImageStore.shared.loadData(for: id)
        guard let data = data, let image = NSImage(data: data) else { return nil }
        let cost = Int(image.size.width * image.size.height * 4)
        Self.fullImageCache.setObject(image, forKey: key, cost: cost)
        return image
    }

    /// Downscaled thumbnail for card display (~220pt wide).
    /// Uses CGImageSource to create a thumbnail directly from compressed data,
    /// avoiding the cost of fully decoding the image into memory.
    var thumbnail: NSImage? {
        let key = id as NSUUID
        if let cached = Self.thumbnailCache.object(forKey: key) {
            return cached
        }
        // Try to generate thumbnail directly from compressed data (no full decode)
        let data = imageData ?? ImageStore.shared.loadData(for: id)
        guard let data = data else { return nil }
        if let thumb = Self.createThumbnailFromData(data, maxDimension: 440) {
            let cost = Int(thumb.size.width * thumb.size.height * 4)
            Self.thumbnailCache.setObject(thumb, forKey: key, cost: cost)
            return thumb
        }
        return nil
    }

    /// Evict full-resolution image from cache (call after preview/paste is done).
    static func evictFullImage(for id: UUID) {
        fullImageCache.removeObject(forKey: id as NSUUID)
    }

    /// Process-stable FNV-1a hash of raw bytes. Used for image dedup identity.
    static func stableHash(of data: Data) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            for byte in buf {
                hash = (hash ^ UInt64(byte)) &* 0x1000_0000_01b3
            }
        }
        return String(hash, radix: 16)
    }

    /// Create a thumbnail directly from compressed image data using CGImageSource.
    /// This avoids fully decoding the image into an uncompressed bitmap.
    private static func createThumbnailFromData(_ data: Data, maxDimension: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
    }

    /// Image dimensions parsed from the content string (e.g. "1920×1080")
    /// or read from the compressed data via CGImageSource — avoids loading the full image.
    var imageDimensions: String? {
        // Content is stored as "WIDTHxHEIGHT" at capture time — try parsing it first
        let parts = content.split(separator: "×")
        if parts.count == 2, let w = Int(parts[0].trimmingCharacters(in: .whitespaces)),
           let h = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
            return "\(w) × \(h)"
        }
        // Fallback: read dimensions from compressed data metadata (no full decode)
        let data = imageData ?? ImageStore.shared.loadData(for: id)
        guard let data = data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return "\(width) × \(height)"
    }
    
    var fileIcon: NSImage? {
        guard type == .file, let urls = fileURLs, let firstURL = urls.first else { return nil }
        return NSWorkspace.shared.icon(forFile: firstURL.path)
    }
    
    // Unique identifier for deduplication
    var uniqueIdentifier: String {
        switch type {
        case .image:
            // Use stable content hash for deduplication (survives relaunches
            // and imageData being released to disk)
            if let hash = imageHash {
                return "image-\(hash)"
            }
            return "image-\(id.uuidString)"
        case .file:
            if let urls = fileURLs {
                return "file-\(urls.map { $0.path }.sorted().joined(separator: ","))"
            }
            return "file-\(id.uuidString)"
        default:
            return content
        }
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
            && lhs.content == rhs.content
            && lhs.type == rhs.type
            && lhs.linkMetadata === rhs.linkMetadata
            && lhs.hasRTF == rhs.hasRTF
            && lhs.detectedTags == rhs.detectedTags
    }
}

// MARK: - Codable Serialization Wrapper

/// Lightweight Codable wrapper for persisting ClipboardItem to disk.
/// Intentionally omits non-Codable fields (NSImage icon, LinkMetadata)
/// which can be reconstructed at load time.
struct CodableSourceApp: Codable {
    let bundleIdentifier: String?
    let name: String

    init(from sourceApp: SourceApp) {
        self.bundleIdentifier = sourceApp.bundleIdentifier
        self.name = sourceApp.name
    }

    func toSourceApp() -> SourceApp {
        // Icon is resolved lazily from the shared cache — no need to load here
        return SourceApp(bundleIdentifier: bundleIdentifier, name: name, icon: nil)
    }
}

struct CodableClipboardItem: Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipboardItem.ClipboardType
    let hasImage: Bool
    let imageHash: String?
    let hasRTF: Bool
    let fileURLPaths: [String]?
    let sourceApp: CodableSourceApp?
    let rtfBase64: String?  // Legacy: kept for migration from older history.json files
    let detectedTags: Set<ContentTag>?
    /// Link preview facts, saved so links are not all re-fetched from the
    /// network after every launch. The images themselves live in LinkImageStore.
    let linkFetched: Bool?
    let linkTitle: String?
    let linkHasImage: Bool?
    let linkHasIcon: Bool?

    enum CodingKeys: String, CodingKey {
        case id, content, timestamp, type, hasImage, imageHash, hasRTF, fileURLPaths, sourceApp, rtfBase64, detectedTags
        case linkFetched, linkTitle, linkHasImage, linkHasIcon
    }

    init(from item: ClipboardItem) {
        self.id = item.id
        self.content = item.content
        self.timestamp = item.timestamp
        self.type = item.type
        self.hasImage = item.hasImage
        self.imageHash = item.imageHash
        self.hasRTF = item.hasRTF
        self.fileURLPaths = item.fileURLs?.map { $0.path }
        self.sourceApp = item.sourceApp.map { CodableSourceApp(from: $0) }
        // Don't re-serialize RTF to base64 — it's already on disk via RTFStore.
        // Only include base64 if data hasn't been migrated to disk yet.
        self.rtfBase64 = nil
        self.detectedTags = item.detectedTags.isEmpty ? nil : item.detectedTags
        if let meta = item.linkMetadata {
            self.linkFetched = true
            self.linkTitle = meta.title
            self.linkHasImage = meta.hasImage
            self.linkHasIcon = meta.hasIcon
        } else {
            self.linkFetched = nil
            self.linkTitle = nil
            self.linkHasImage = nil
            self.linkHasIcon = nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        type = try container.decode(ClipboardItem.ClipboardType.self, forKey: .type)
        hasImage = try container.decodeIfPresent(Bool.self, forKey: .hasImage) ?? false
        imageHash = try container.decodeIfPresent(String.self, forKey: .imageHash)
        fileURLPaths = try container.decodeIfPresent([String].self, forKey: .fileURLPaths)
        sourceApp = try container.decodeIfPresent(CodableSourceApp.self, forKey: .sourceApp)
        rtfBase64 = try container.decodeIfPresent(String.self, forKey: .rtfBase64)
        detectedTags = try container.decodeIfPresent(Set<ContentTag>.self, forKey: .detectedTags)
        linkFetched = try container.decodeIfPresent(Bool.self, forKey: .linkFetched)
        linkTitle = try container.decodeIfPresent(String.self, forKey: .linkTitle)
        linkHasImage = try container.decodeIfPresent(Bool.self, forKey: .linkHasImage)
        linkHasIcon = try container.decodeIfPresent(Bool.self, forKey: .linkHasIcon)
        // hasRTF: true if the flag is set, OR if legacy base64 data exists, OR if an RTF file exists on disk
        let flagValue = try container.decodeIfPresent(Bool.self, forKey: .hasRTF) ?? false
        hasRTF = flagValue || rtfBase64 != nil || RTFStore.shared.exists(for: id)
    }

    func toClipboardItem() -> ClipboardItem {
        // Migrate legacy base64 RTF data to disk if needed
        if let base64 = rtfBase64, let data = Data(base64Encoded: base64),
           !RTFStore.shared.exists(for: id) {
            RTFStore.shared.save(data: data, for: id)
        }

        let fileURLs = fileURLPaths?.map { URL(fileURLWithPath: $0) }
        let source = sourceApp?.toSourceApp()

        // Restore saved link preview facts; images load lazily from disk
        var restoredLink: LinkMetadata?
        if type == .url, linkFetched == true, let url = URL(string: content) {
            restoredLink = LinkMetadata(
                title: linkTitle, url: url,
                hasImage: linkHasImage ?? false, hasIcon: linkHasIcon ?? false)
        }

        return ClipboardItem(
            id: id,
            content: content,
            timestamp: timestamp,
            type: type,
            imageData: nil,
            hasImage: hasImage,
            imageHash: imageHash,
            fileURLs: fileURLs,
            sourceApp: source,
            linkMetadata: restoredLink,  // nil = fetched on demand when the card appears
            rtfData: nil,       // Loaded on demand from RTFStore
            hasRTF: hasRTF,
            detectedTags: detectedTags ?? []
        )
    }
}
