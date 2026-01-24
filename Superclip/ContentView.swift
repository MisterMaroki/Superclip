//
//  ContentView.swift
//  Superclip
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var navigationState: NavigationState
    var dismiss: (Bool) -> Void  // Bool indicates whether to paste after dismiss
    
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

            // Search bar
            HStack {
                Spacer()
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search clipboard history...", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _ in
                            // Reset selection when search changes
                            navigationState.selectedIndex = 0
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .frame(maxWidth: 400)
                
                Spacer()
            }
            .padding(.vertical, 8)
            
            // Clipboard history list
            if filteredHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: clipboardManager.history.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    
                    Text(clipboardManager.history.isEmpty ? "No clipboard history yet" : "No results found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if clipboardManager.history.isEmpty {
                        Text("Copy something to get started")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemCard(
                                item: item,
                                index: index + 1,
                                isSelected: navigationState.selectedIndex == index,
                                onSelect: {
                                    navigationState.selectedIndex = index
                                    clipboardManager.copyToClipboard(item)
                                    // Auto-dismiss and paste
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        dismiss(true)
                                    }
                                },
                                onDelete: {
                                    clipboardManager.deleteItem(item)
                                    // Adjust selected index if needed
                                    if navigationState.selectedIndex >= filteredHistory.count - 1 {
                                        navigationState.selectedIndex = max(0, filteredHistory.count - 2)
                                    }
                                }
                            )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .onAppear {
                            // Update item count for navigation
                            navigationState.itemCount = filteredHistory.count
                            // Reset selection when filtered history changes
                            if navigationState.selectedIndex >= filteredHistory.count {
                                navigationState.selectedIndex = 0
                            }
                        }
                        .onChange(of: filteredHistory.count) { newCount in
                            navigationState.itemCount = newCount
                        }
                        .onChange(of: navigationState.selectedIndex) { newIndex in
                            // Scroll to selected item
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
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
    }
}

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var typeIcon: String {
        switch item.type {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "doc"
        case .url: return "link"
        case .rtf: return "doc.richtext"
        }
    }
    
    var typeColor: Color {
        switch item.type {
        case .text: return .primary
        case .image: return .purple
        case .file: return .blue
        case .url: return .green
        case .rtf: return .orange
        }
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
            // Header with type and timestamp
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: typeIcon)
                        .font(.caption)
                        .foregroundStyle(typeColor)
                    Text(item.type.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(item.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            
            // Content area
            VStack(alignment: .leading, spacing: 8) {
                contentView
                
                Spacer(minLength: 0)
                
                // Footer with info and index
                HStack {
                    Text(footerText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(index)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(width: 280, height: 160)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
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
                    .foregroundStyle(.secondary)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Delete")
            .padding(8)
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
            .lineLimit(6)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
    
    var imageContentView: some View {
        Group {
            if let nsImage = item.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .cornerRadius(6)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: 120)
            }
        }
    }
    
    var fileContentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let urls = item.fileURLs {
                ForEach(urls.prefix(3), id: \.self) { url in
                    HStack(spacing: 8) {
                        if let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "doc")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                        }
                        
                        Text(url.lastPathComponent)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                if urls.count > 3 {
                    Text("+ \(urls.count - 3) more...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var urlContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 24))
                .foregroundStyle(.green)
            
            Text(item.content)
                .font(.system(size: 11))
                .foregroundStyle(.blue)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}