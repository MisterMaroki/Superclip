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

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipboardType
    let imageData: Data?
    let fileURLs: [URL]?
    let sourceApp: SourceApp?
    
    enum ClipboardType: String, Codable {
        case text
        case image
        case file
        case url
        case rtf
    }
    
    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), type: ClipboardType = .text, imageData: Data? = nil, fileURLs: [URL]? = nil, sourceApp: SourceApp? = nil) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.type = type
        self.imageData = imageData
        self.fileURLs = fileURLs
        self.sourceApp = sourceApp
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
