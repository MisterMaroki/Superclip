//
//  PasteStackView.swift
//  Superclip
//

import SwiftUI

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
    
    var appColor: Color {
        item.sourceApp?.accentColor ?? Color(nsColor: .systemGray)
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
            
            // Type indicator
            typeIcon
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
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
            HStack(alignment: .top, spacing: 6) {
                if let urls = item.fileURLs, let firstURL = urls.first {
                    if let icon = NSWorkspace.shared.icon(forFile: firstURL.path) as NSImage? {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    Text(urls.count == 1 ? firstURL.lastPathComponent : "\(urls.count) files")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
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
    var typeIcon: some View {
        switch item.type {
        case .image:
            Image(systemName: "photo")
        case .file:
            Image(systemName: "doc")
        case .url:
            Image(systemName: "link")
        case .rtf:
            Image(systemName: "text.badge.star")
        case .text:
            Image(systemName: "text.alignleft")
        }
    }
}

// MARK: - Safe Array Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
