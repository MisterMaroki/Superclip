//
//  PasteStackView.swift
//  Superclip
//

import SwiftUI
import AVFoundation

enum PasteStackViewMode {
    case list
    case grid

    mutating func toggle() {
        self = self == .list ? .grid : .list
    }
}

struct PasteStackView: View {
    @ObservedObject var pasteStackManager: PasteStackManager
    @ObservedObject var navigationState: NavigationState
    var onClose: () -> Void
    /// Lets the panel size itself for the layout in use
    var onViewModeChanged: ((PasteStackViewMode) -> Void)? = nil
    var dismiss: (Bool) -> Void

    @State private var viewMode: PasteStackViewMode = .list
    @State private var userOverrodeViewMode = false

    /// Items in paste order: row 1 is what the next Cmd+V pastes.
    var sortedItems: [ClipboardItem] {
        pasteStackManager.newestFirst
            ? pasteStackManager.stackItems.reversed()
            : pasteStackManager.stackItems
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
                        .foregroundStyle(.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close paste stack")
                .accessibilityLabel("Close paste stack")

                Text("Paste Stack")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.9))

                Spacer()

                if !pasteStackManager.stackItems.isEmpty {
                    Text(pasteStackManager.stackItems.count == 1
                         ? "1 item" : "\(pasteStackManager.stackItems.count) items")
                        .font(.system(size: 10))
                        .foregroundStyle(Brand.gray600)
                }

                // View mode toggle
                if !pasteStackManager.stackItems.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode.toggle()
                            userOverrodeViewMode = true
                        }
                    } label: {
                        Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 11))
                            .foregroundStyle(.primary.opacity(0.6))
                            .padding(4)
                            .background(Color.primary.opacity(0.1))
                    }
                    .buttonStyle(.plain)
                    .help(viewMode == .grid ? "List view" : "Grid view")
                    .accessibilityLabel(viewMode == .grid ? "Switch to list view" : "Switch to grid view")
                }

                // Sort button
                if !pasteStackManager.stackItems.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            pasteStackManager.newestFirst.toggle()
                            navigationState.selectedIndex = 0
                        }
                    } label: {
                        VStack(spacing: 0) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(pasteStackManager.newestFirst ? Brand.gray400 : Brand.black)
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(pasteStackManager.newestFirst ? Brand.black : Brand.gray400)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.1))
                    }
                    .buttonStyle(.plain)
                    .help(pasteStackManager.newestFirst
                          ? "Pasting newest first. Click to paste oldest first."
                          : "Pasting oldest first. Click to paste newest first.")
                    .accessibilityLabel("Paste order")
                }

                // Clear button
                if !pasteStackManager.stackItems.isEmpty {
                    Button {
                        pasteStackManager.clearStack()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Clear stack")
                    .accessibilityLabel("Clear stack")
                }

            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Brand.gray100)

            // Stack content
            if pasteStackManager.stackItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 28))
                        .foregroundStyle(.primary.opacity(0.45))

                    Text("Copy a few things in a row")
                        .font(.system(size: 12))
                        .foregroundStyle(Brand.gray600)

                    Text("Then press \u{2318}V repeatedly to paste them in order")
                        .font(.system(size: 10))
                        .foregroundStyle(Brand.gray600)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let itemsToDisplay = sortedItems
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        if viewMode == .grid {
                            gridContent(items: itemsToDisplay)
                        } else {
                            listContent(items: itemsToDisplay)
                        }
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
        .background(Brand.white)
        .clipShape(Rectangle())
        .overlay(Rectangle().stroke(Brand.gray300, lineWidth: 1))
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
            // Auto-switch to grid when many images accumulate
            if !userOverrodeViewMode {
                let imageCount = pasteStackManager.stackItems.filter { $0.type == .image }.count
                if imageCount >= 3 && viewMode == .list {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewMode = .grid
                    }
                }
            }
        }
        .onChange(of: viewMode) { newMode in
            onViewModeChanged?(newMode)
        }
        .onChange(of: navigationState.shouldSelectAndDismiss) { shouldSelect in
            if shouldSelect {
                navigationState.shouldSelectAndDismiss = false
                guard let item = selectedItem else { return }
                pasteStackManager.prepareToPaste(item)

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

    // MARK: - Grid Content

    @ViewBuilder
    private func gridContent(items: [ClipboardItem]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 75, maximum: 100), spacing: 6)],
            spacing: 6
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                PasteStackGridTile(
                    item: item,
                    index: index + 1,
                    isSelected: navigationState.selectedIndex == index,
                    onSelect: {
                        navigationState.selectedIndex = index
                        pasteStackManager.prepareToPaste(item)
                        if navigationState.selectedIndex >= items.count {
                            navigationState.selectedIndex = max(0, items.count - 1)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss(true)
                        }
                    },
                    onDelete: {
                        pasteStackManager.removeItem(item)
                        if navigationState.selectedIndex >= items.count {
                            navigationState.selectedIndex = max(0, items.count - 1)
                        }
                    }
                )
                .id(item.id)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .id("grid-\(pasteStackManager.newestFirst ? "desc" : "asc")")
    }

    // MARK: - List Content

    @ViewBuilder
    private func listContent(items: [ClipboardItem]) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                PasteStackItemRow(
                    item: item,
                    index: index + 1,
                    isSelected: navigationState.selectedIndex == index,
                    onSelect: {
                        navigationState.selectedIndex = index
                        pasteStackManager.prepareToPaste(item)

                        // Adjust selected index if needed
                        if navigationState.selectedIndex >= items.count {
                            navigationState.selectedIndex = max(0, items.count - 1)
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss(true)
                        }
                    },
                    onDelete: {
                        pasteStackManager.removeItem(item)
                        if navigationState.selectedIndex >= items.count {
                            navigationState.selectedIndex = max(0, items.count - 1)
                        }
                    }
                )
                .id(item.id)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .id(pasteStackManager.newestFirst ? "desc" : "asc")
    }
}

// MARK: - Grid Tile

struct PasteStackGridTile: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Content
            tileContent
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

            // Index badge
            Text("\(index)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Brand.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Rectangle().fill(Brand.black.opacity(0.55)))
                .padding(4)

            // Delete button on hover/selection
            if isHovered || isSelected {
                HStack {
                    Spacer()
                    Button {
                        onDelete()
                    } label: {
                        // Adaptive x on an adaptive disc: readable on the tile
                        // colour in both themes and over image tiles
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Brand.white, Brand.black)
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(
                    isSelected ? Brand.black : (isHovered ? Brand.gray400 : Color.clear),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    @ViewBuilder
    var tileContent: some View {
        switch item.type {
        case .image:
            // Thumbnail only — falling back to item.nsImage decodes the
            // full-resolution image inside a list row's body.
            if let thumb = item.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderTile(icon: "photo")
            }
        case .file:
            if let urls = item.fileURLs, let firstURL = urls.first, urls.count == 1,
               Self.imageExtensions.contains(firstURL.pathExtension.lowercased()) {
                // Cached, downsampled, loaded off the main thread. Decoding the
                // file here re-ran on every hover in and out.
                FileImageThumbnailView(url: firstURL)
            } else {
                placeholderTile(icon: "doc")
            }
        case .url:
            textTile(icon: "link", text: item.content, tint: .blue)
        case .text:
            textTile(icon: "text.alignleft", text: item.content, tint: .primary)
        }
    }

    @ViewBuilder
    func placeholderTile(icon: String) -> some View {
        ZStack {
            Color.primary.opacity(0.08)
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    func textTile(icon: String, text: String, tint: Color) -> some View {
        ZStack {
            Color.primary.opacity(0.06)
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(tint.opacity(0.7))
                Text(text)
                    .font(.system(size: 8))
                    .foregroundStyle(Brand.gray600)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - List Row

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
            // Detect format from magic bytes — read only the first 12 bytes, not the whole file
            if let data = item.imageData ?? ImageStore.shared.loadHeader(for: item.id, byteCount: 12) {
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
        if let cached = MediaThumbnailCache.shared.object(forKey: url as NSURL) {
            mediaThumbnail = cached
            return
        }
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
                    MediaThumbnailCache.shared.setObject(thumbnail, forKey: url as NSURL)
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
                .foregroundStyle(Brand.gray700)
                .frame(width: 20)
                .padding(.top, 2)

            // Colored indicator bar
            Rectangle()
                .fill(Brand.gray300)
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
                        .foregroundStyle(Brand.gray600)
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
                        .foregroundStyle(.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(isSelected ? Color.primary.opacity(0.15) : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
        )
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1)
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
                // Thumbnail only — falling back to item.nsImage decodes the
            // full-resolution image inside a list row's body.
            if let thumb = item.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Rectangle())
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
                .foregroundStyle(Brand.gray600)
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
                        // System icon — decoding the real image at full
                        // resolution for a 32×32 badge re-ran on every
                        // body evaluation (including hover changes).
                        Image(nsImage: NSWorkspace.shared.icon(forFile: firstURL.path))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Rectangle())
                    } else if isVideoFile(firstURL) {
                        // Video file - show video thumbnail with play overlay
                        ZStack {
                            if let thumbnail = mediaThumbnail {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(Rectangle())
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                            }
                            // Play icon overlay
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 14))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.white, Color.black.opacity(0.55))
                                .shadow(radius: 2)
                        }
                        .onAppear {
                            generateVideoThumbnail(for: firstURL)
                        }
                    } else if isAudioFile(firstURL) {
                        // Audio file - show waveform icon
                        ZStack {
                            Rectangle()
                                .fill(Brand.gray200)
                                .frame(width: 32, height: 32)
                            Image(systemName: "waveform")
                                .font(.system(size: 14))
                                .foregroundStyle(Brand.gray600)
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
                            .foregroundStyle(Brand.gray600)
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
            return "Video \u{2022} \(ext.uppercased())"
        } else if isAudioFile(url) {
            return "Audio \u{2022} \(ext.uppercased())"
        } else if isImageFile(url) {
            return "Image \u{2022} \(ext.uppercased())"
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
