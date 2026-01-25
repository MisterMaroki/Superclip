//
//  PasteStackView.swift
//  Superclip
//

import SwiftUI
import AVFoundation

enum SortOrder {
    case ascending  // Oldest first (first copied at top)
    case descending // Newest first (last copied at top)
    
    var label: String {
        switch self {
        case .ascending:
            return "Oldest first"
        case .descending:
            return "Newest first"
        }
    }
    
    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

struct PasteStackView: View {
    @ObservedObject var pasteStackManager: PasteStackManager
    @ObservedObject var navigationState: NavigationState
    var onClose: () -> Void
    var dismiss: (Bool) -> Void
    
    @State private var sortOrder: SortOrder = .ascending
    
    var sortedItems: [ClipboardItem] {
        switch sortOrder {
        case .ascending:
            return pasteStackManager.stackItems // Already in order of copy (oldest first)
        case .descending:
            return pasteStackManager.stackItems.reversed()
        }
    }
    
    var selectedItem: ClipboardItem? {
        guard !sortedItems.isEmpty,
              navigationState.selectedIndex >= 0,
              navigationState.selectedIndex < sortedItems.count else {
            return nil
        }
        return sortedItems[navigationState.selectedIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) { 
                // Close button
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close paste stack")

                Text("Paste Stack")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
                
                if !pasteStackManager.stackItems.isEmpty {
                    Text("\(pasteStackManager.stackItems.count) items")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                // Sort button
                if !pasteStackManager.stackItems.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sortOrder.toggle()
                            navigationState.selectedIndex = 0
                        }
                    } label: {
                        VStack(spacing: 0) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(sortOrder == .ascending ? .white.opacity(0.9) : .white.opacity(0.35))
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(sortOrder == .descending ? .white.opacity(0.9) : .white.opacity(0.35))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(sortOrder.label)
                }
                
                // Clear button
                if !pasteStackManager.stackItems.isEmpty {
                    Button {
                        pasteStackManager.clearStack()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Clear stack")
                }
             
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
            
            // Stack content
            if pasteStackManager.stackItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text("Copy items to add to stack")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("⌘C to copy, then select to paste in order")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let itemsToDisplay = sortedItems
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(Array(itemsToDisplay.enumerated()), id: \.element.id) { index, item in
                                PasteStackItemRow(
                                    item: item,
                                    index: index + 1,
                                    isSelected: navigationState.selectedIndex == index,
                                    onSelect: {
                                        navigationState.selectedIndex = index
                                        pasteStackManager.copyToClipboard(item)
                                        pasteStackManager.removeItem(item)
                                        
                                        // Adjust selected index if needed
                                        if navigationState.selectedIndex >= itemsToDisplay.count {
                                            navigationState.selectedIndex = max(0, itemsToDisplay.count - 1)
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            dismiss(true)
                                        }
                                    },
                                    onDelete: {
                                        pasteStackManager.removeItem(item)
                                        if navigationState.selectedIndex >= itemsToDisplay.count {
                                            navigationState.selectedIndex = max(0, itemsToDisplay.count - 1)
                                        }
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .id(sortOrder == .ascending ? "asc" : "desc")
                    }
                    .onChange(of: navigationState.selectedIndex) { newIndex in
                        if let item = itemsToDisplay[safe: newIndex] {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            navigationState.itemCount = sortedItems.count
            navigationState.selectedIndex = 0
        }
        .onChange(of: pasteStackManager.stackItems.count) { newCount in
            navigationState.itemCount = newCount
            // When a new item is added, keep selection at current position
            // unless the stack was empty
            if newCount > 0 && navigationState.selectedIndex >= newCount {
                navigationState.selectedIndex = newCount - 1
            }
        }
        .onChange(of: navigationState.shouldSelectAndDismiss) { shouldSelect in
            if shouldSelect, let item = selectedItem {
                pasteStackManager.copyToClipboard(item)
                pasteStackManager.removeItem(item)
                navigationState.shouldSelectAndDismiss = false
                
                // Adjust selected index
                if navigationState.selectedIndex >= sortedItems.count {
                    navigationState.selectedIndex = max(0, sortedItems.count - 1)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss(true)
                }
            }
        }
    }
}

struct PasteStackItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var mediaThumbnail: NSImage?
    
    var appColor: Color {
        item.sourceApp?.accentColor ?? Color(nsColor: .systemGray)
    }
    
    // Get file extension for display
    var fileExtension: String? {
        switch item.type {
        case .file:
            if let urls = item.fileURLs, let firstURL = urls.first, urls.count == 1 {
                let ext = firstURL.pathExtension.lowercased()
                return ext.isEmpty ? nil : ext
            }
            return nil
        case .image:
            // Check if there's a file URL with extension
            if let urls = item.fileURLs, let firstURL = urls.first {
                let ext = firstURL.pathExtension.lowercased()
                return ext.isEmpty ? nil : ext
            }
            // Try to detect from image data
            if let data = item.imageData {
                if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
                if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
                if data.starts(with: [0x47, 0x49, 0x46]) { return "gif" }
                if data.count >= 12 {
                    let webpHeader = Array(data[8..<12])
                    if webpHeader == [0x57, 0x45, 0x42, 0x50] { return "webp" }
                }
            }
            return nil
        default:
            return nil
        }
    }
    
    // Media file extensions
    private static let videoExtensions = ["mp4", "mov", "avi", "mkv", "webm", "m4v", "wmv", "flv"]
    private static let audioExtensions = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff"]
    private static let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
    
    private func isVideoFile(_ url: URL) -> Bool {
        Self.videoExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func isAudioFile(_ url: URL) -> Bool {
        Self.audioExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        Self.imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func isMediaFile(_ url: URL) -> Bool {
        isVideoFile(url) || isAudioFile(url) || isImageFile(url)
    }
    
    private func generateVideoThumbnail(for url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 64, height: 64)
            
            let time = CMTime(seconds: 1, preferredTimescale: 600)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                DispatchQueue.main.async {
                    self.mediaThumbnail = thumbnail
                }
            } catch {
                // Fallback - no thumbnail available
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 1) {
            // Index badge
            Text("\(index)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 20)
                .padding(.top, 2)
            
            // Colored indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(appColor)
                .frame(width: 3, height: 32)
            
            // Content preview
            contentPreview
                .frame(maxWidth: .infinity, alignment: .topLeading)
            
            // Type indicator with extension
            HStack(spacing: 3) {
                typeIcon
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                if let ext = fileExtension {
                    Text(ext.uppercased())
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
            
            // Delete button (visible on hover)
            if isHovered || isSelected {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.15) : (isHovered ? Color.white.opacity(0.08) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    @ViewBuilder
    var contentPreview: some View {
        switch item.type {
        case .image:
            HStack(alignment: .top, spacing: 6) {
                if let nsImage = item.nsImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .cornerRadius(4)
                        .clipped()
                }
                Text(item.imageDimensions ?? "Image")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        case .file:
            fileContentPreview
        case .url:
            Text(item.content)
                .font(.system(size: 11))
                .foregroundStyle(.blue)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        default:
            Text(item.content)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
    
    @ViewBuilder
    var fileContentPreview: some View {
        if let urls = item.fileURLs, let firstURL = urls.first {
            HStack(alignment: .top, spacing: 6) {
                // Show thumbnail for media files
                if urls.count == 1 {
                    if isImageFile(firstURL) {
                        // Image file - show image thumbnail
                        if let image = NSImage(contentsOf: firstURL) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .cornerRadius(4)
                                .clipped()
                        } else {
                            defaultFileIcon(for: firstURL)
                        }
                    } else if isVideoFile(firstURL) {
                        // Video file - show video thumbnail with play overlay
                        ZStack {
                            if let thumbnail = mediaThumbnail {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(4)
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(4)
                            }
                            // Play icon overlay
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 2)
                        }
                        .onAppear {
                            generateVideoThumbnail(for: firstURL)
                        }
                    } else if isAudioFile(firstURL) {
                        // Audio file - show waveform icon
                        ZStack {
                            Rectangle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 32, height: 32)
                                .cornerRadius(4)
                            Image(systemName: "waveform")
                                .font(.system(size: 14))
                                .foregroundStyle(.purple)
                        }
                    } else {
                        defaultFileIcon(for: firstURL)
                    }
                } else {
                    // Multiple files - show default icon
                    defaultFileIcon(for: firstURL)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(urls.count == 1 ? firstURL.lastPathComponent : "\(urls.count) files")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if urls.count == 1 {
                        Text(mediaTypeLabel(for: firstURL))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func defaultFileIcon(for url: URL) -> some View {
        if let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 24, height: 24)
        }
    }
    
    func mediaTypeLabel(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if isVideoFile(url) {
            return "Video • \(ext.uppercased())"
        } else if isAudioFile(url) {
            return "Audio • \(ext.uppercased())"
        } else if isImageFile(url) {
            return "Image • \(ext.uppercased())"
        }
        return ext.uppercased()
    }
    
    @ViewBuilder
    var typeIcon: some View {
        switch item.type {
        case .image:
            Image(systemName: "photo")
        case .file:
            fileTypeIcon
        case .url:
            Image(systemName: "link")
        case .rtf:
            Image(systemName: "text.badge.star")
        case .text:
            Image(systemName: "text.alignleft")
        }
    }
    
    @ViewBuilder
    var fileTypeIcon: some View {
        if let urls = item.fileURLs, let firstURL = urls.first, urls.count == 1 {
            if isVideoFile(firstURL) {
                Image(systemName: "video")
            } else if isAudioFile(firstURL) {
                Image(systemName: "waveform")
            } else if isImageFile(firstURL) {
                Image(systemName: "photo")
            } else {
                Image(systemName: "doc")
            }
        } else {
            Image(systemName: "doc")
        }
    }
}

// MARK: - Safe Array Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
