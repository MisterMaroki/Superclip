//
//  ContentView.swift
//  Superclip
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import Combine

// Custom identifier for clipboard item drag and drop
private let clipboardItemIDType = "com.omarmaroki.superclip.clipboard-item-id"

// Global state to track dragged item (fallback approach)
class DragState: ObservableObject {
    static let shared = DragState()
    @Published var draggedItemId: UUID?
}

enum ViewMode: Equatable {
    case clipboard
    case pinboard(Pinboard)
}

struct ContentView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var pinboardManager: PinboardManager
    var dismiss: (Bool) -> Void  // Bool indicates whether to paste after dismiss
    var onPreview: ((ClipboardItem, Int) -> Void)?  // Item and index
    var onEditingPinboardChanged: ((Bool) -> Void)?  // Called when editing state changes
    var onTextSnipe: (() -> Void)?  // Called when text sniper button is tapped
    var onSearchingChanged: ((Bool) -> Void)?  // Called when search field visibility changes
    var onSearchFocusChanged: ((Bool) -> Void)?  // Called when search field gains/loses actual focus
    
    @FocusState private var isSearchFocused: Bool
    @State private var searchText: String = ""
    @State private var showSearchField: Bool = false
    @State private var viewMode: ViewMode = .clipboard
    @State private var editingPinboard: Pinboard?
    @State private var editingPinboardName: String = ""
    @State private var editingPinboardColor: PinboardColor = .red
    @FocusState private var isEditingPinboard: Bool
    @State private var dragLocation: CGPoint? = nil
    @State private var dragMonitorTimer: Timer? = nil
    
    var currentItems: [ClipboardItem] {
        switch viewMode {
        case .clipboard:
            return filteredHistory
        case .pinboard(let pinboard):
            let pinboardItems = pinboardManager.getItems(for: pinboard, from: clipboardManager.history)
            if searchText.isEmpty {
                return pinboardItems
            }
            return pinboardItems.filter { item in
                if item.content.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if item.type.rawValue.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
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
    }
    
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
        guard !currentItems.isEmpty, navigationState.selectedIndex >= 0, navigationState.selectedIndex < currentItems.count else {
            return nil
        }
        return currentItems[navigationState.selectedIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // New header design
            headerView
                .padding(.top, 12)
            
            // Clipboard history list
            itemsListView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(
            // Invisible overlay to detect drag outside
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: DragState.shared.draggedItemId) { itemId in
                        if itemId != nil {
                            // Start monitoring mouse location when drag starts
                            // Get frame in screen coordinates
                            let frame = geometry.frame(in: .global)
                            DispatchQueue.main.async {
                                startDragMonitoring(frame: frame)
                            }
                        } else {
                            // Stop monitoring when drag ends
                            stopDragMonitoring()
                        }
                    }
                    .onAppear {
                        // Also monitor when view appears in case drag is already active
                        if DragState.shared.draggedItemId != nil {
                            let frame = geometry.frame(in: .global)
                            startDragMonitoring(frame: frame)
                        }
                    }
            }
        )
        .onAppear {
            // Update item count
            navigationState.itemCount = currentItems.count
            navigationState.selectedIndex = 0
        }
        .onChange(of: currentItems.count) { newCount in
            navigationState.itemCount = newCount
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
                showSearchField = true
                navigationState.shouldFocusSearch = false
                // Focus with small delay for UI to render
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
        }
        .onChange(of: showSearchField) { isShowing in
            onSearchingChanged?(isShowing)
        }
        .onChange(of: isSearchFocused) { isFocused in
            onSearchFocusChanged?(isFocused)
            // When focus is gained, append any accumulated pending text
            if isFocused && !navigationState.pendingSearchText.isEmpty {
                searchText += navigationState.pendingSearchText
                navigationState.pendingSearchText = ""
            }
        }
        .onChange(of: navigationState.shouldCloseSearch) { shouldClose in
            if shouldClose {
                navigationState.shouldCloseSearch = false
                // Close search if empty (arrow navigation with empty search)
                if searchText.isEmpty {
                    showSearchField = false
                }
            }
        }
        .onChange(of: navigationState.shouldClearAndCloseSearch) { shouldClose in
            if shouldClose {
                navigationState.shouldClearAndCloseSearch = false
                searchText = ""
                showSearchField = false
                isSearchFocused = false
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
                if navigationState.selectedIndex >= currentItems.count - 1 {
                    navigationState.selectedIndex = max(0, currentItems.count - 2)
                }
            }
        }
        .onChange(of: viewMode) { _ in
            navigationState.selectedIndex = 0
            navigationState.itemCount = currentItems.count
        }
        .onDisappear {
            stopDragMonitoring()
        }
    }
    
    // MARK: - Drag Monitoring
    
    private func startDragMonitoring(frame: CGRect) {
        stopDragMonitoring() // Clean up any existing timer
        
        let dismissCallback = dismiss
        
        // Get the actual window frame - look for ContentPanel specifically
        // Try multiple ways to find the window
        var window: NSWindow?
        for w in NSApp.windows {
            if w is ContentPanel {
                window = w
                break
            }
        }
        if window == nil {
            window = NSApp.windows.first(where: { $0.isKeyWindow })
        }
        if window == nil {
            window = NSApp.windows.first(where: { $0.isMainWindow })
        }
        if window == nil {
            window = NSApp.windows.first
        }
        
        guard let window = window else {
            return
        }
        
        let windowFrame = window.frame
        
        dragMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard DragState.shared.draggedItemId != nil else {
                timer.invalidate()
                return
            }
            
            // Get current mouse location in screen coordinates (bottom-left origin)
            let mouseLocation = NSEvent.mouseLocation
            
            // Window frame and mouse location are both in screen coordinates with bottom-left origin
            let isOutside = mouseLocation.x < windowFrame.minX || 
                           mouseLocation.x > windowFrame.maxX ||
                           mouseLocation.y < windowFrame.minY || 
                           mouseLocation.y > windowFrame.maxY
            
            if isOutside {
                // Close the drawer when dragged outside
                timer.invalidate()
                DragState.shared.draggedItemId = nil // Clear drag state
                DispatchQueue.main.async {
                    dismissCallback(false)
                }
            }
        }
        
        // Make sure timer runs on main run loop in common mode
        if let timer = dragMonitorTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopDragMonitoring() {
        dragMonitorTimer?.invalidate()
        dragMonitorTimer = nil
    }
    
    // Start monitoring directly from drag callback (more reliable)
    private func startDragMonitoringFromDrag() {
        stopDragMonitoring() // Clean up any existing timer
        
        let dismissCallback = dismiss
        
        // Get the actual window frame - look for ContentPanel specifically
        var window: NSWindow?
        for w in NSApp.windows {
            if w is ContentPanel {
                window = w
                break
            }
        }
        if window == nil {
            window = NSApp.windows.first(where: { $0.isKeyWindow })
        }
        if window == nil {
            window = NSApp.windows.first(where: { $0.isMainWindow })
        }
        if window == nil {
            window = NSApp.windows.first
        }
        
        guard let window = window else {
            return
        }
        
        let windowFrame = window.frame
        
        dragMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard DragState.shared.draggedItemId != nil else {
                timer.invalidate()
                return
            }
            
            // Get current mouse location in screen coordinates (bottom-left origin)
            let mouseLocation = NSEvent.mouseLocation
            
            // Window frame and mouse location are both in screen coordinates with bottom-left origin
            let isOutside = mouseLocation.x < windowFrame.minX || 
                           mouseLocation.x > windowFrame.maxX ||
                           mouseLocation.y < windowFrame.minY || 
                           mouseLocation.y > windowFrame.maxY
            
            if isOutside {
                // Close the drawer when dragged outside
                timer.invalidate()
                DragState.shared.draggedItemId = nil // Clear drag state
                DispatchQueue.main.async {
                    dismissCallback(false)
                }
            }
        }
        
        // Make sure timer runs on main run loop in common mode
        if let timer = dragMonitorTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // MARK: - Header View
    
    var headerView: some View {
        HStack(spacing: showSearchField ? 8 : 16) {
            // Search field or icon
            if showSearchField {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("Search...", text: $searchText)
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
                .frame(width: 200)
            } else {
                HeaderIconButton(icon: "magnifyingglass") {
                    showSearchField = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isSearchFocused = true
                    }
                }
            }

            // Clipboard tab
            ClipboardTabButton(
                isSelected: {
                    if case .clipboard = viewMode {
                        return true
                    }
                    return false
                }(),
                isCompact: showSearchField,
                onSelect: {
                    showSearchField = false
                    searchText = ""
                    viewMode = .clipboard
                }
            )

            // Pinboard tabs
            ForEach(pinboardManager.pinboards) { pinboard in
                if editingPinboard?.id == pinboard.id && !showSearchField {
                    // Editing mode (only when not searching)
                    PinboardEditView(
                        name: $editingPinboardName,
                        color: $editingPinboardColor,
                        isFocused: $isEditingPinboard,
                        onSave: {
                            var updated = pinboard
                            updated.name = editingPinboardName.isEmpty ? "Untitled" : editingPinboardName
                            updated.color = editingPinboardColor

                            pinboardManager.updatePinboard(updated)

                            editingPinboard = nil
                            isEditingPinboard = false
                            onEditingPinboardChanged?(false)

                            if case .pinboard(let current) = viewMode, current.id == pinboard.id {
                                viewMode = .pinboard(updated)
                            }
                        },
                        onCancel: {
                            editingPinboard = nil
                            isEditingPinboard = false
                            onEditingPinboardChanged?(false)
                        }
                    )
                } else {
                    // Display mode (normal or compact when searching)
                    PinboardTabButton(
                        pinboard: pinboard,
                        isSelected: {
                            if case .pinboard(let current) = viewMode {
                                return current.id == pinboard.id
                            }
                            return false
                        }(),
                        isCompact: showSearchField,
                        onSelect: {
                            viewMode = .pinboard(pinboard)
                        },
                        onEdit: {
                            editingPinboard = pinboard
                            editingPinboardName = pinboard.name
                            editingPinboardColor = pinboard.color
                            isEditingPinboard = true
                            onEditingPinboardChanged?(true)
                        },
                        onDelete: {
                            if case .pinboard(let current) = viewMode, current.id == pinboard.id {
                                viewMode = .clipboard
                            }
                            pinboardManager.deletePinboard(pinboard)
                        },
                        onDrop: { itemId in
                            pinboardManager.addItem(itemId, to: pinboard)
                            if let updatedPinboard = pinboardManager.pinboards.first(where: { $0.id == pinboard.id }) {
                                viewMode = .pinboard(updatedPinboard)
                            } else {
                                viewMode = .pinboard(pinboard)
                            }
                        }
                    )
                }
            }

            // Add pinboard button (hide when searching)
            if !showSearchField {
                HeaderIconButton(icon: "plus") {
                    let newPinboard = pinboardManager.createPinboard(name: "Untitled", color: .red)
                    editingPinboard = newPinboard
                    editingPinboardName = "Untitled"
                    editingPinboardColor = .red
                    isEditingPinboard = true
                    onEditingPinboardChanged?(true)
                    viewMode = .pinboard(newPinboard)
                }
            }

            // Text sniper button (always visible)
            HeaderIconButton(icon: "text.viewfinder", action: {
                onTextSnipe?()
            }, helpText: "Text Sniper (Cmd+Shift+`)")
        }
    }
    
    // MARK: - Items List View
    
    var itemsListView: some View {
        Group {
            if currentItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: viewMode == .clipboard && clipboardManager.history.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text(emptyStateMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    if viewMode == .clipboard && clipboardManager.history.isEmpty {
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
                            ForEach(Array(currentItems.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemCard(
                                    item: item,
                                    index: index + 1,
                                    isSelected: navigationState.selectedIndex == index,
                                    quickAccessNumber: navigationState.isCommandHeld && index < 10 ? (index == 9 ? 0 : index + 1) : nil,
                                    holdProgress: navigationState.holdProgress,
                                    onSelect: {
                                        navigationState.selectedIndex = index
                                        clipboardManager.copyToClipboard(item)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            dismiss(true)
                                        }
                                    },
                                    onDragStart: {
                                        DragState.shared.draggedItemId = item.id
                                        // Immediately start monitoring when drag begins
                                        startDragMonitoringFromDrag()
                                    },
                                    onDragEnd: {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            DragState.shared.draggedItemId = nil
                                        }
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .onAppear {
                            navigationState.itemCount = currentItems.count
                            if navigationState.selectedIndex >= currentItems.count {
                                navigationState.selectedIndex = 0
                            }
                        }
                        .onChange(of: currentItems.count) { newCount in
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
    }
    
    var emptyStateMessage: String {
        switch viewMode {
        case .clipboard:
            return clipboardManager.history.isEmpty ? "No clipboard history yet" : "No results found"
        case .pinboard:
            return searchText.isEmpty ? "This pinboard is empty" : "No results found"
        }
    }
            
}

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let quickAccessNumber: Int? // 1-9 for first 9, 0 for 10th, nil if not in first 10 or command not held
    let holdProgress: Double // 0...1 for hold-to-edit progress
    let onSelect: () -> Void
    var onDragStart: (() -> Void)? = nil
    var onDragEnd: (() -> Void)? = nil
    
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
        .overlay {
            // Hold-to-edit progress ring (only for editable items when selected and holding)
            if isSelected && (item.type == .text || item.type == .url) && holdProgress > 0 {
                ZStack {
                    // Background ring (subtle)
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 50, height: 50)

                    // Progress ring (fills clockwise)
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(
                            Color.white.opacity(0.9),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90)) // Start from top

                    // Edit icon in center
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .opacity(0.7 + holdProgress * 0.3)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: holdProgress)
            }
        }
        .animation(.easeOut(duration: 0.15), value: quickAccessNumber != nil)
        // Hold-to-edit glow effect (layered for soft bloom) - only for selected card
        .shadow(
            color: Color.white.opacity(isSelected ? holdProgress * 0.5 : 0),
            radius: isSelected ? 6 * holdProgress : 0
        )
        .shadow(
            color: Color.blue.opacity(isSelected ? holdProgress * 0.3 : 0),
            radius: isSelected ? 10 * holdProgress : 0
        )
        .animation(.easeOut(duration: 0.12), value: isSelected ? holdProgress : 0)
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
            onDragStart?()
            return createDragItemProvider(with: item.id)
        }
        .onChange(of: DragState.shared.draggedItemId) { newValue in
            if newValue == nil {
                onDragEnd?()
            }
        }
    }

    private func createDragItemProvider(with itemId: UUID) -> NSItemProvider {
        // Set global state for drag tracking
        DragState.shared.draggedItemId = itemId
        
        let provider = NSItemProvider()
        
        // Register the item ID as a custom type for pinboard drops
        let itemIdString = itemId.uuidString
        provider.registerDataRepresentation(forTypeIdentifier: clipboardItemIDType, visibility: .all) { completion in
            completion(itemIdString.data(using: .utf8), nil)
            return nil
        }
        
        // Also register as plain text with a special prefix as fallback
        provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
            let text = "SUPERCLIP_ITEM_ID:\(itemIdString)"
            completion(text.data(using: .utf8), nil)
            return nil
        }

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
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .background(Color(nsColor: .separatorColor).opacity(0.1))
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
        // Prevent vertical expansion - keep text at top
        textView.isVerticallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textStorage?.setAttributedString(attributedString)
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.textStorage?.setAttributedString(attributedString)
    }
}

// MARK: - Header Components

struct HeaderIconButton: View {
    let icon: String
    let action: () -> Void
    var helpText: String? = nil

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(isHovered ? Color.white.opacity(0.15) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(helpText ?? "")
    }
}

struct ClipboardTabButton: View {
    let isSelected: Bool
    let isCompact: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            if isCompact {
                Image(systemName: "sparkle.text.clipboard")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(isSelected ? Color(white: 0.3) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
                    .cornerRadius(6)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle.text.clipboard")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                    Text("Clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(white: 0.3) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
                .cornerRadius(12)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct PinboardTabButton: View {
    let pinboard: Pinboard
    let isSelected: Bool
    let isCompact: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDrop: (UUID) -> Void

    @State private var isDragOver = false
    @State private var isHovered = false
    @ObservedObject private var dragState = DragState.shared

    private var backgroundColor: Color {
        if isDragOver {
            return Color.white.opacity(0.4)
        } else if dragState.draggedItemId != nil {
            return Color.white.opacity(0.2)
        } else if isSelected {
            return Color.white.opacity(0.15)
        } else if isHovered {
            return Color.white.opacity(0.1)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        Group {
            if isCompact {
                Circle()
                    .fill(pinboard.color.color)
                    .frame(width: 8, height: 8)
                    .padding(8)
                    .background(backgroundColor)
                    .cornerRadius(6)
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(pinboard.color.color)
                        .frame(width: 6, height: 6)
                    Text(pinboard.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(backgroundColor)
                .cornerRadius(6)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .onDrop(of: [clipboardItemIDType, UTType.plainText.identifier, UTType.image.identifier, UTType.fileURL.identifier, UTType.url.identifier], isTargeted: $isDragOver) { providers in
            // Use global state as primary method since it's more reliable
            if let itemId = dragState.draggedItemId {
                DispatchQueue.main.async {
                    onDrop(itemId)
                    dragState.draggedItemId = nil
                }
                return true
            }
            
            // Fallback: try to extract from providers
            guard let provider = providers.first else { return false }
            
            // Try custom type first
            if provider.hasItemConformingToTypeIdentifier(clipboardItemIDType) {
                _ = provider.loadDataRepresentation(forTypeIdentifier: clipboardItemIDType) { data, error in
                    guard let data = data,
                          let itemIdString = String(data: data, encoding: .utf8),
                          let itemId = UUID(uuidString: itemIdString) else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        onDrop(itemId)
                        dragState.draggedItemId = nil
                    }
                }
                return true
            }
            
            // Try plain text with prefix
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, error in
                    guard let data = data,
                          let text = String(data: data, encoding: .utf8),
                          text.hasPrefix("SUPERCLIP_ITEM_ID:") else {
                        return
                    }
                    
                    let itemIdString = String(text.dropFirst("SUPERCLIP_ITEM_ID:".count))
                    guard let itemId = UUID(uuidString: itemIdString) else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        onDrop(itemId)
                        dragState.draggedItemId = nil
                    }
                }
                return true
            }
            
            return false
        }
        .contextMenu {
            Button("Edit") {
                onEdit()
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Text("Delete")
            }
        }
    }
}

struct PinboardEditView: View {
    @Binding var name: String
    @Binding var color: PinboardColor
    @FocusState.Binding var isFocused: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var showingColorPicker = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Color picker
            Menu {
                ForEach(PinboardColor.allCases, id: \.self) { pinboardColor in
                    Button {
                        color = pinboardColor
                    } label: {
                        HStack {
                            Circle()
                                .fill(pinboardColor.color)
                                .frame(width: 12, height: 12)
                            Text(pinboardColor.rawValue.capitalized)
                            if color == pinboardColor {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Circle()
                    .fill(color.color)
                    .frame(width: 8, height: 8)
            }
            .menuStyle(.borderlessButton)
            
            // Name text field
            TextField("Untitled", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .focused($isFocused)
                .frame(width: 120)
                .onSubmit {
                    onSave()
                }
                .onKeyPress(.return) {
                    onSave()
                    return .handled
                }
                .onKeyPress(.escape) {
                    onCancel()
                    return .handled
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(white: 0.25))
        .cornerRadius(6)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
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