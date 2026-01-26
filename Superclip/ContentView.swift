//
//  ContentView.swift
//  Superclip
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var navigationState: NavigationState
    var dismiss: (Bool) -> Void  // Bool indicates whether to paste after dismiss
    var onPreview: ((ClipboardItem, Int) -> Void)?  // Item and index
    
    @FocusState private var isSearchFocused: Bool
    @State private var searchText: String = ""
    
    var filteredHistory: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardManager.history
        }
        return clipboardManager.history.filter { item in
            // Search in content
            if item.content.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            // Search in type name
            if item.type.rawValue.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            // Search in file names
            if let urls = item.fileURLs {
                for url in urls {
                    if url.lastPathComponent.localizedCaseInsensitiveContains(searchText) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    var selectedItem: ClipboardItem? {
        guard !filteredHistory.isEmpty, navigationState.selectedIndex >= 0, navigationState.selectedIndex < filteredHistory.count else {
            return nil
        }
        return filteredHistory[navigationState.selectedIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar with search
            HStack(spacing: 16) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("Search clipboard history...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _ in
                            navigationState.selectedIndex = 0
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: 300)
                
                Spacer()
                
                // Item count
                if !filteredHistory.isEmpty {
                    Text("\(filteredHistory.count) items")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
            
            // Clipboard history list
            if filteredHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: clipboardManager.history.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text(clipboardManager.history.isEmpty ? "No clipboard history yet" : "No results found")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    if clipboardManager.history.isEmpty {
                        Text("Copy something to get started")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 14) {
                            ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemCard(
                                    item: item,
                                    index: index + 1,
                                    isSelected: navigationState.selectedIndex == index,
                                    quickAccessNumber: navigationState.isCommandHeld && index < 10 ? (index == 9 ? 0 : index + 1) : nil,
                                    onSelect: {
                                        navigationState.selectedIndex = index
                                        clipboardManager.copyToClipboard(item)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            dismiss(true)
                                        }
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .onAppear {
                            navigationState.itemCount = filteredHistory.count
                            if navigationState.selectedIndex >= filteredHistory.count {
                                navigationState.selectedIndex = 0
                            }
                        }
                        .onChange(of: filteredHistory.count) { newCount in
                            navigationState.itemCount = newCount
                        }
                        .onChange(of: navigationState.selectedIndex) { newIndex in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(newIndex, anchor: .center)
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Update item count
            navigationState.itemCount = filteredHistory.count
            navigationState.selectedIndex = 0
        }
        .onChange(of: navigationState.shouldSelectAndDismiss) { shouldSelect in
            if shouldSelect, let item = selectedItem {
                clipboardManager.copyToClipboard(item)
                navigationState.shouldSelectAndDismiss = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss(true)
                }
            }
        }
        .onChange(of: navigationState.shouldFocusSearch) { shouldFocus in
            if shouldFocus {
                isSearchFocused = true
                navigationState.shouldFocusSearch = false
            }
        }
        .onChange(of: navigationState.shouldShowPreview) { shouldShow in
            if shouldShow, let item = selectedItem {
                navigationState.shouldShowPreview = false
                onPreview?(item, navigationState.selectedIndex)
            }
        }
        .onChange(of: navigationState.shouldDeleteCurrent) { shouldDelete in
            if shouldDelete, let item = selectedItem {
                navigationState.shouldDeleteCurrent = false
                clipboardManager.deleteItem(item)
                // Adjust selection if needed
                if navigationState.selectedIndex >= filteredHistory.count - 1 {
                    navigationState.selectedIndex = max(0, filteredHistory.count - 2)
                }
            }
        }
    }
}

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let quickAccessNumber: Int? // 1-9 for first 9, 0 for 10th, nil if not in first 10 or command not held
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: type + time on left, app icon on right
            HStack(spacing: 6) {
                // Type label
                Text(item.typeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                
                // Time ago
                Text(item.timeAgo)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                // Source app icon on right
                if let icon = item.sourceApp?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(white: 0.15))
            
            // Content area
            ZStack(alignment: .bottomTrailing) {
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                // Floating char count for text only
                if item.type == .text {
                    Text("\(item.content.count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.white.opacity(0.8) : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .bottomLeading) {
            if let number = quickAccessNumber {
                Text(number == 0 ? "0" : "\(number)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.accentColor.opacity(0.9))
                    .cornerRadius(5)
                    .padding(6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.15), value: quickAccessNumber != nil)
        .shadow(color: .black.opacity(isSelected ? 0.3 : 0.15), radius: isSelected ? 8 : 4, y: 2)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDrag {
            createDragItemProvider()
        }
    }

    private func createDragItemProvider() -> NSItemProvider {
        let provider = NSItemProvider()

        switch item.type {
        case .text:
            // For text, provide both plain text and RTF if available
            if let rtfData = item.rtfData {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.rtf.identifier, visibility: .all) { completion in
                    completion(rtfData, nil)
                    return nil
                }
            }
            provider.registerObject(item.content as NSString, visibility: .all)

        case .image:
            if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                provider.registerObject(nsImage, visibility: .all)
            }

        case .file:
            if let urls = item.fileURLs {
                for url in urls {
                    provider.registerFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier, fileOptions: [], visibility: .all) { completion in
                        completion(url, false, nil)
                        return nil
                    }
                }
            }

        case .url:
            if let url = URL(string: item.content) {
                provider.registerObject(url as NSURL, visibility: .all)
            }
            // Also provide as plain text
            provider.registerObject(item.content as NSString, visibility: .all)
        }

        return provider
    }

    @ViewBuilder
    var contentView: some View {
        switch item.type {
        case .image:
            imageContentView
        case .file:
            fileContentView
        case .url:
            urlContentView
        default:
            textContentView
        }
    }
    
    var textContentView: some View {
        Group {
            if let attributedString = item.attributedString {
                // Display rich text preview
                RichTextCardPreview(attributedString: attributedString)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
            } else {
                Text(item.content)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(8)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
            }
        }
    }
    
    var imageContentView: some View {
        Group {
            if let nsImage = item.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(4)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // Media file extensions
    private static let videoExtensions = ["mp4", "mov", "avi", "mkv", "webm", "m4v", "wmv", "flv"]
    private static let audioExtensions = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff"]
    private static let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
    
    private func isImageFile(_ url: URL) -> Bool {
        Self.imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func isVideoFile(_ url: URL) -> Bool {
        Self.videoExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func isAudioFile(_ url: URL) -> Bool {
        Self.audioExtensions.contains(url.pathExtension.lowercased())
    }
    
    var fileContentView: some View {
        Group {
            if let urls = item.fileURLs {
                // Check if it's a single media file - show preview
                if urls.count == 1, let url = urls.first {
                    if isImageFile(url), let image = NSImage(contentsOf: url) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .cornerRadius(4)
                    } else if isVideoFile(url) {
                        VideoThumbnailView(url: url)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .cornerRadius(4)
                    } else if isAudioFile(url) {
                        AudioFileThumbnailView(url: url)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .cornerRadius(4)
                    } else {
                        singleFileView(url: url)
                    }
                } else {
                    // Multiple files - show list
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(urls.prefix(4), id: \.self) { url in
                            HStack(spacing: 6) {
                                fileThumbnail(for: url)
                                
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        
                        if urls.count > 4 {
                            Text("+ \(urls.count - 4) more...")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
    }
    
    @ViewBuilder
    private func singleFileView(url: URL) -> some View {
        VStack(spacing: 8) {
            if let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
            }
            Text(url.lastPathComponent)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func fileThumbnail(for url: URL) -> some View {
        if isImageFile(url), let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .cornerRadius(3)
                .clipped()
        } else if isVideoFile(url) {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .cornerRadius(3)
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
            }
        } else if isAudioFile(url) {
            ZStack {
                Rectangle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .cornerRadius(3)
                Image(systemName: "waveform")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)
            }
        } else if let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "doc")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }
    
    var urlContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Link metadata image or placeholder
            if let metadata = item.linkMetadata, let image = metadata.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                // Placeholder with link icon
                VStack {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .separatorColor).opacity(0.2))
            }
            
            // Footer with title and URL
            VStack(alignment: .leading, spacing: 2) {
                if let metadata = item.linkMetadata, let title = metadata.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                Text(item.linkMetadata?.displayURL ?? item.content)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

// MARK: - Video Thumbnail View

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: NSImage?
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            
            // Play button overlay
            VStack {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4)
                
                Text("VIDEO")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 400, height: 300)
            
            let time = CMTime(seconds: 1, preferredTimescale: 600)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
            } catch {
                // Failed to generate thumbnail
            }
        }
    }
}

// MARK: - Audio File Thumbnail View

struct AudioFileThumbnailView: View {
    let url: URL
    
    var body: some View {
        VStack(spacing: 12) {
            // Waveform visualization
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple.opacity(0.6))
                        .frame(width: 6, height: CGFloat.random(in: 15...50))
                }
            }
            
            // Audio icon and label
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AUDIO")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(url.pathExtension.uppercased())
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.purple.opacity(0.1))
    }
}

// MARK: - Rich Text Card Preview

struct RichTextCardPreview: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.maximumNumberOfLines = 8
        textView.textContainer?.lineBreakMode = .byTruncatingTail
        textView.textStorage?.setAttributedString(attributedString)
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.textStorage?.setAttributedString(attributedString)
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}