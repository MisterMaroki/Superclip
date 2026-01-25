//
//  ContentView.swift
//  Superclip
//

import SwiftUI

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
                
                // Clipboard label
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                    Text("Clipboard")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.7))
                
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
                                    onSelect: {
                                        navigationState.selectedIndex = index
                                        clipboardManager.copyToClipboard(item)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            dismiss(true)
                                        }
                                    },
                                    onDelete: {
                                        clipboardManager.deleteItem(item)
                                        if navigationState.selectedIndex >= filteredHistory.count - 1 {
                                            navigationState.selectedIndex = max(0, filteredHistory.count - 2)
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
    }
}

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    private let cardWidth: CGFloat = 220
    private let cardHeight: CGFloat = 180
    
    var appColor: Color {
        item.sourceApp?.accentColor ?? Color(nsColor: .systemGray)
    }
    
    var footerText: String {
        switch item.type {
        case .image:
            return item.imageDimensions ?? "Image"
        case .file:
            if let urls = item.fileURLs {
                return urls.count == 1 ? "1 file" : "\(urls.count) files"
            }
            return "File"
        case .url:
            return "URL"
        default:
            return "\(item.content.count) characters"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Colored header bar with app info - Paste style
            HStack(spacing: 8) {
                // App icon
                if let icon = item.sourceApp?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                // App name
                Text(item.sourceApp?.name ?? item.type.rawValue.capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Timestamp
                Text(item.timeAgo)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(appColor)
            
            // Content area
            VStack(alignment: .leading, spacing: 0) {
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                // Footer with info and index
                HStack {
                    Text(footerText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(index)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .separatorColor).opacity(0.3))
                        .cornerRadius(4)
                }
            }
            .padding(10)
            .frame(width: cardWidth, height: cardHeight - 32) // Subtract header height
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.white.opacity(0.8) : Color.clear, lineWidth: 2)
        )
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
        .overlay(alignment: .topTrailing) {
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .help("Delete")
            .padding(6)
        }
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
        Text(item.content)
            .font(.system(size: 12))
            .foregroundStyle(.primary)
            .lineLimit(7)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    var fileContentView: some View {
        Group {
            if let urls = item.fileURLs {
                // Check if it's a single image file - show image preview
                if urls.count == 1, let url = urls.first, isImageFile(url), let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(4)
                } else {
                    // Multiple files or non-image files - show list
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(urls.prefix(4), id: \.self) { url in
                            HStack(spacing: 6) {
                                // Show thumbnail for images, icon for others
                                if isImageFile(url), let image = NSImage(contentsOf: url) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 20, height: 20)
                                        .cornerRadius(3)
                                        .clipped()
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    var urlContentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Link")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Text(item.content)
                .font(.system(size: 11))
                .foregroundStyle(.blue)
                .lineLimit(5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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