//
//  ClipboardItem.swift
//  Superclip
//

import Foundation
import AppKit

struct SourceApp: Equatable {
    let bundleIdentifier: String?
    let name: String
    let icon: NSImage?
    
    init(bundleIdentifier: String?, name: String, icon: NSImage?) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.icon = icon
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

// Link metadata for URL previews
class LinkMetadata: NSObject {
    let title: String?
    let url: URL
    let imageData: Data?
    let iconData: Data?

    init(title: String?, url: URL, imageData: Data?, iconData: Data? = nil) {
        self.title = title
        self.url = url
        self.imageData = imageData
        self.iconData = iconData
        super.init()
    }

    var image: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    var icon: NSImage? {
        guard let data = iconData else { return nil }
        return NSImage(data: data)
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

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipboardType
    let imageData: Data?
    let fileURLs: [URL]?
    let sourceApp: SourceApp?
    var linkMetadata: LinkMetadata?
    var rtfData: Data?  // Rich text formatting data (RTF format)
    var detectedTags: Set<ContentTag>  // Auto-detected content sub-categories

    enum ClipboardType: String, Codable {
        case text
        case image
        case file
        case url
    }

    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), type: ClipboardType = .text, imageData: Data? = nil, fileURLs: [URL]? = nil, sourceApp: SourceApp? = nil, linkMetadata: LinkMetadata? = nil, rtfData: Data? = nil, detectedTags: Set<ContentTag> = []) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.type = type
        self.imageData = imageData
        self.fileURLs = fileURLs
        self.sourceApp = sourceApp
        self.linkMetadata = linkMetadata
        self.rtfData = rtfData
        self.detectedTags = detectedTags
    }

    // Get attributed string from RTF data
    var attributedString: NSAttributedString? {
        guard let data = rtfData else { return nil }
        return NSAttributedString(rtf: data, documentAttributes: nil)
    }

    // Check if item has rich text formatting
    var hasRichText: Bool {
        rtfData != nil
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
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var nsImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }
    
    var imageDimensions: String? {
        guard let image = nsImage else { return nil }
        let width = Int(image.size.width)
        let height = Int(image.size.height)
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
            // Use hash of image data for deduplication
            if let data = imageData {
                return "image-\(data.hashValue)"
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
            && lhs.linkMetadata === rhs.linkMetadata
            && lhs.rtfData == rhs.rtfData
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
        var icon: NSImage?
        if let bundleId = bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            icon = NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return SourceApp(bundleIdentifier: bundleIdentifier, name: name, icon: icon)
    }
}

struct CodableClipboardItem: Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipboardItem.ClipboardType
    let imageBase64: String?
    let fileURLPaths: [String]?
    let sourceApp: CodableSourceApp?
    let rtfBase64: String?
    let detectedTags: Set<ContentTag>?

    init(from item: ClipboardItem) {
        self.id = item.id
        self.content = item.content
        self.timestamp = item.timestamp
        self.type = item.type
        self.imageBase64 = item.imageData?.base64EncodedString()
        self.fileURLPaths = item.fileURLs?.map { $0.path }
        self.sourceApp = item.sourceApp.map { CodableSourceApp(from: $0) }
        self.rtfBase64 = item.rtfData?.base64EncodedString()
        self.detectedTags = item.detectedTags.isEmpty ? nil : item.detectedTags
    }

    func toClipboardItem() -> ClipboardItem {
        let imageData = imageBase64.flatMap { Data(base64Encoded: $0) }
        let fileURLs = fileURLPaths?.map { URL(fileURLWithPath: $0) }
        let rtfData = rtfBase64.flatMap { Data(base64Encoded: $0) }
        let source = sourceApp?.toSourceApp()

        return ClipboardItem(
            id: id,
            content: content,
            timestamp: timestamp,
            type: type,
            imageData: imageData,
            fileURLs: fileURLs,
            sourceApp: source,
            linkMetadata: nil,  // Re-fetched on demand
            rtfData: rtfData,
            detectedTags: detectedTags ?? []
        )
    }
}
