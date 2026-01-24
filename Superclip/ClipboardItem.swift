//
//  ClipboardItem.swift
//  Superclip
//

import Foundation
import AppKit

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipboardType
    let imageData: Data?
    let fileURLs: [URL]?
    
    enum ClipboardType: String, Codable {
        case text
        case image
        case file
        case url
        case rtf
    }
    
    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), type: ClipboardType = .text, imageData: Data? = nil, fileURLs: [URL]? = nil) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.type = type
        self.imageData = imageData
        self.fileURLs = fileURLs
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
        return lhs.id == rhs.id
    }
}
