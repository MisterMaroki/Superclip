//
//  ContentView.swift
//  Superclip
//

import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

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

/// Filter categories for the filter bar. Maps to ClipboardType + ContentTag.
enum FilterTag: String, CaseIterable, Equatable {
  case all = "All"
  case links = "Links"
  case images = "Images"
  case files = "Files"
  case code = "Code"
  case colors = "Colors"
  case emails = "Emails"
  case json = "JSON"
  case phones = "Phones"

  var icon: String {
    switch self {
    case .all: return "tray.full"
    case .links: return "link"
    case .images: return "photo"
    case .files: return "doc"
    case .code: return "chevron.left.forwardslash.chevron.right"
    case .colors: return "paintpalette"
    case .emails: return "envelope"
    case .json: return "curlybraces"
    case .phones: return "phone"
    }
  }

  /// Check whether a clipboard item matches this filter.
  func matches(_ item: ClipboardItem) -> Bool {
    switch self {
    case .all: return true
    case .links: return item.type == .url
    case .images: return item.type == .image
    case .files: return item.type == .file
    case .code: return item.detectedTags.contains(.code)
    case .colors: return item.detectedTags.contains(.color)
    case .emails: return item.detectedTags.contains(.email)
    case .json: return item.detectedTags.contains(.json)
    case .phones: return item.detectedTags.contains(.phone)
    }
  }
}

struct ContentView: View {
  @ObservedObject var clipboardManager: ClipboardManager
  @ObservedObject var navigationState: NavigationState
  @ObservedObject var pinboardManager: PinboardManager
  @ObservedObject var settings: SettingsManager
  var dismiss: (Bool) -> Void  // Bool indicates whether to paste after dismiss
  var onPreview: ((ClipboardItem, Int, CGFloat) -> Void)?  // Item, index, and card center X
  var onEditingPinboardChanged: ((Bool) -> Void)?  // Called when editing state changes
  var onTextSnipe: (() -> Void)?  // Called when text sniper button is tapped
  var onSearchingChanged: ((Bool) -> Void)?  // Called when search field visibility changes
  var onSearchFocusChanged: ((Bool) -> Void)?  // Called when search field gains/loses actual focus
  var onEditItem: ((ClipboardItem) -> Void)?  // Called to open rich text editor for an item
  var onOpenSettings: (() -> Void)?  // Called to open settings window

  @FocusState private var isSearchFocused: Bool
  @State private var searchText: String = ""
  @State private var showSearchField: Bool = false
  @State private var viewMode: ViewMode = .clipboard
  @State private var selectedFilter: FilterTag = .all
  @State private var editingPinboard: Pinboard?
  @State private var editingPinboardName: String = ""
  @FocusState private var isEditingPinboard: Bool
  @State private var dragLocation: CGPoint? = nil
  @State private var dragMonitorTimer: Timer? = nil
  @State private var dragMouseUpMonitor: Any? = nil
  @State private var cardCenterXPositions: [Int: CGFloat] = [:]  // index -> center X in screen coords

  var currentItems: [ClipboardItem] {
    switch viewMode {
    case .clipboard:
      return filteredHistory
    case .pinboard(let pinboard):
      let pinboardItems = pinboardManager.getItems(for: pinboard, from: clipboardManager.history)
      if searchText.isEmpty {
        return pinboardItems
      }
      // Use fuzzy search with ranked results for pinboard items too
      return FuzzySearch.search(query: searchText, in: pinboardItems)
    }
  }

  var filteredHistory: [ClipboardItem] {
    if searchText.isEmpty {
      return clipboardManager.history
    }
    // Use fuzzy search with ranked results
    return FuzzySearch.search(query: searchText, in: clipboardManager.history)
  }

  var selectedItem: ClipboardItem? {
    guard !currentItems.isEmpty, navigationState.selectedIndex >= 0,
      navigationState.selectedIndex < currentItems.count
    else {
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
        VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
        Color.black.opacity(0.15)
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
      // Update item count and reset selection
      updateNavigationForCurrentItems()
    }
    .onChange(of: currentItems.count) { _ in
      // Always sync itemCount when items change
      updateNavigationForCurrentItems()
    }
    .onChange(of: navigationState.shouldSelectAndDismiss) { shouldSelect in
      if shouldSelect, let item = selectedItem {
        clipboardManager.copyToClipboard(item)
        settings.playSound()
        navigationState.shouldSelectAndDismiss = false
        DispatchQueue.main.asyncAfter(deadline: .now()) {
          dismiss(settings.pasteAfterSelecting)
        }
      }
    }
    .onChange(of: navigationState.shouldFocusSearch) { shouldFocus in
      if shouldFocus {
        showSearchField = true
        navigationState.shouldFocusSearch = false
        // Focus with small delay for UI to render
        DispatchQueue.main.asyncAfter(deadline: .now()) {
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
        let centerX = cardCenterXPositions[navigationState.selectedIndex] ?? 0
        onPreview?(item, navigationState.selectedIndex, centerX)
      }
    }
    .onChange(of: navigationState.selectedIndex) { newIndex in
      // Update preview if it's visible (for navigation while preview is open)
      // Small delay to let GeometryReader update for off-screen cards
      if navigationState.isPreviewVisible, newIndex < currentItems.count {
        updatePreviewForIndex(newIndex, attempt: 1)
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
    .onChange(of: navigationState.shouldMovePinboardLeft) { shouldMove in
      if shouldMove {
        navigationState.shouldMovePinboardLeft = false
        moveToPreviousPinboard()
      }
    }
    .onChange(of: navigationState.shouldMovePinboardRight) { shouldMove in
      if shouldMove {
        navigationState.shouldMovePinboardRight = false
        moveToNextPinboard()
      }
    }
    .onDisappear {
      stopDragMonitoring()
    }
  }

  // MARK: - Drag Monitoring

  private func startDragMonitoring(frame: CGRect) {
    stopDragMonitoring()  // Clean up any existing timer

    let dismissCallback = dismiss

    dragMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
      guard DragState.shared.draggedItemId != nil else {
        timer.invalidate()
        return
      }

      // Get current window frame dynamically (in case window moved)
      var currentWindow: NSWindow?
      for w in NSApp.windows {
        if w is ContentPanel && w.isVisible {
          currentWindow = w
          break
        }
      }

      guard let windowFrame = currentWindow?.frame else {
        timer.invalidate()
        return
      }

      // Get current mouse location in screen coordinates (bottom-left origin)
      let mouseLocation = NSEvent.mouseLocation

      // Window frame and mouse location are both in screen coordinates with bottom-left origin
      let isOutside =
        mouseLocation.x < windowFrame.minX || mouseLocation.x > windowFrame.maxX
        || mouseLocation.y < windowFrame.minY || mouseLocation.y > windowFrame.maxY

      if isOutside {
        // Close the drawer when dragged outside
        timer.invalidate()
        DragState.shared.draggedItemId = nil  // Clear drag state
        DispatchQueue.main.async {
          dismissCallback(false)
        }
      }
    }

    // Make sure timer runs on main run loop in common mode
    if let timer = dragMonitorTimer {
      RunLoop.main.add(timer, forMode: .common)
    }

    // Monitor for mouse up to detect when drag ends (cancelled or completed)
    dragMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [self] event in
      // When mouse is released, clear drag state after a brief delay
      // (allows drop handlers to process first)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        DragState.shared.draggedItemId = nil
      }
      return event
    }
  }

  private func updateNavigationForCurrentItems() {
    navigationState.itemCount = currentItems.count
    if navigationState.selectedIndex >= currentItems.count && currentItems.count > 0 {
      navigationState.selectedIndex = 0
    }
  }

  private func updatePreviewForIndex(_ index: Int, attempt: Int) {
    let delay: Double = attempt == 1 ? 0.05 : 0.15
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      guard navigationState.isPreviewVisible,
        index == navigationState.selectedIndex,
        index < currentItems.count
      else { return }

      let item = currentItems[index]
      let centerX = cardCenterXPositions[index] ?? 0

      if centerX > 0 {
        onPreview?(item, index, centerX)
      } else if attempt < 3 {
        // Retry if position not ready yet
        updatePreviewForIndex(index, attempt: attempt + 1)
      }
    }
  }

  private func stopDragMonitoring() {
    dragMonitorTimer?.invalidate()
    dragMonitorTimer = nil
    if let monitor = dragMouseUpMonitor {
      NSEvent.removeMonitor(monitor)
      dragMouseUpMonitor = nil
    }
  }

  // MARK: - Pinboard Navigation

  private func moveToPreviousPinboard() {
    let pinboards = pinboardManager.pinboards
    switch viewMode {
    case .clipboard:
      // From clipboard, go to last pinboard if any exist
      if let lastPinboard = pinboards.last {
        viewMode = .pinboard(lastPinboard)
      }
    case .pinboard(let current):
      // Find current pinboard index and go to previous
      if let currentIndex = pinboards.firstIndex(where: { $0.id == current.id }) {
        if currentIndex > 0 {
          viewMode = .pinboard(pinboards[currentIndex - 1])
        } else {
          // At first pinboard, go to clipboard
          viewMode = .clipboard
        }
      } else {
        viewMode = .clipboard
      }
    }
  }

  private func moveToNextPinboard() {
    let pinboards = pinboardManager.pinboards
    switch viewMode {
    case .clipboard:
      // From clipboard, go to first pinboard if any exist
      if let firstPinboard = pinboards.first {
        viewMode = .pinboard(firstPinboard)
      }
    case .pinboard(let current):
      // Find current pinboard index and go to next
      if let currentIndex = pinboards.firstIndex(where: { $0.id == current.id }) {
        if currentIndex < pinboards.count - 1 {
          viewMode = .pinboard(pinboards[currentIndex + 1])
        } else {
          // At last pinboard, wrap to clipboard
          viewMode = .clipboard
        }
      } else {
        viewMode = .clipboard
      }
    }
  }

  // Start monitoring directly from drag callback (more reliable)
  private func startDragMonitoringFromDrag() {
    stopDragMonitoring()  // Clean up any existing timer

    let dismissCallback = dismiss

    dragMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
      guard DragState.shared.draggedItemId != nil else {
        timer.invalidate()
        return
      }

      // Get current window frame dynamically (in case window moved)
      var currentWindow: NSWindow?
      for w in NSApp.windows {
        if w is ContentPanel && w.isVisible {
          currentWindow = w
          break
        }
      }

      guard let windowFrame = currentWindow?.frame else {
        timer.invalidate()
        return
      }

      // Get current mouse location in screen coordinates (bottom-left origin)
      let mouseLocation = NSEvent.mouseLocation

      // Window frame and mouse location are both in screen coordinates with bottom-left origin
      let isOutside =
        mouseLocation.x < windowFrame.minX || mouseLocation.x > windowFrame.maxX
        || mouseLocation.y < windowFrame.minY || mouseLocation.y > windowFrame.maxY

      if isOutside {
        // Close the drawer when dragged outside
        timer.invalidate()
        DragState.shared.draggedItemId = nil  // Clear drag state
        DispatchQueue.main.async {
          dismissCallback(false)
        }
      }
    }

    // Make sure timer runs on main run loop in common mode
    if let timer = dragMonitorTimer {
      RunLoop.main.add(timer, forMode: .common)
    }

    // Monitor for mouse up to detect when drag ends (cancelled or completed)
    dragMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [self] event in
      // When mouse is released, clear drag state after a brief delay
      // (allows drop handlers to process first)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        DragState.shared.draggedItemId = nil
      }
      return event
    }
  }

  // MARK: - Header View

  var headerView: some View {
    ZStack {
      // Centered content
      HStack(spacing: showSearchField ? 8 : 16) {
        // Search field or icon
        if showSearchField {
          HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 13))
              .foregroundStyle(.primary.opacity(0.5))
            TextField("Search...", text: $searchText)
              .textFieldStyle(.plain)
              .font(.system(size: 14))
              .foregroundStyle(.primary)
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
                  .foregroundStyle(.primary.opacity(0.5))
              }
              .buttonStyle(.plain)
            }

          }
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .background(Color.primary.opacity(0.1))
          .cornerRadius(8)
          .frame(width: 220)
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
          itemCount: settings.showItemCount ? clipboardManager.history.count : nil,
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
              color: pinboard.color,
              isFocused: $isEditingPinboard,
              onSave: {
                var updated = pinboard
                updated.name = editingPinboardName.isEmpty ? "Untitled" : editingPinboardName

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
              itemCount: settings.showItemCount ? pinboard.itemIds.count : nil,
              onSelect: {
                viewMode = .pinboard(pinboard)
              },
              onEdit: {
                editingPinboard = pinboard
                editingPinboardName = pinboard.name
                isEditingPinboard = true
                onEditingPinboardChanged?(true)
              },
              onDelete: {
                if case .pinboard(let current) = viewMode, current.id == pinboard.id {
                  viewMode = .clipboard
                }
                pinboardManager.deletePinboard(pinboard)
              },
              onColorChange: { newColor in
                var updated = pinboard
                updated.color = newColor
                pinboardManager.updatePinboard(updated)
                if case .pinboard(let current) = viewMode, current.id == pinboard.id {
                  viewMode = .pinboard(updated)
                }
              },
              onDrop: { itemId in
                pinboardManager.addItem(itemId, to: pinboard)
                if let updatedPinboard = pinboardManager.pinboards.first(where: {
                  $0.id == pinboard.id
                }) {
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
            isEditingPinboard = true
            onEditingPinboardChanged?(true)
            viewMode = .pinboard(newPinboard)
          }
        }

        // Text sniper button (always visible)
        HeaderIconButton(
          icon: "text.viewfinder",
          action: {
            onTextSnipe?()
          }, helpText: "Text Sniper (Cmd+Shift+`)")
      }

      // Settings button - far right
      HStack {
        Spacer()
        HeaderIconButton(
          icon: "gearshape",
          action: {
            onOpenSettings?()
          },
          helpText: "Settings"
        )
        .padding(.trailing, 8)
      }
    }
  }

  // MARK: - Filter Bar View

  var filterBarView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(FilterTag.allCases, id: \.self) { tag in
          FilterPillButton(
            tag: tag,
            isSelected: selectedFilter == tag,
            onSelect: {
              withAnimation(.easeOut(duration: 0.15)) {
                selectedFilter = (selectedFilter == tag && tag != .all) ? .all : tag
              }
            }
          )
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 6)
    }
  }

  // MARK: - Items List View

  var itemsListView: some View {
    Group {
      if currentItems.isEmpty {
        VStack(spacing: 12) {
          Image(
            systemName: viewMode == .clipboard && clipboardManager.history.isEmpty
              ? "doc.on.clipboard" : "magnifyingglass"
          )
          .font(.system(size: 40))
          .foregroundStyle(.primary.opacity(0.3))

          Text(emptyStateMessage)
            .font(.system(size: 13))
            .foregroundStyle(.primary.opacity(0.5))

          if viewMode == .clipboard && clipboardManager.history.isEmpty {
            Text("Copy something to get started")
              .font(.system(size: 12))
              .foregroundStyle(.primary.opacity(0.35))
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
                  quickAccessNumber: navigationState.isCommandHeld && index < 10
                    ? (index == 9 ? 0 : index + 1) : nil,
                  holdProgress: navigationState.holdProgress,
                  showSourceAppIcons: settings.showSourceAppIcons,
                  showTimestamps: settings.showTimestamps,
                  showLinkPreviews: settings.showLinkPreviews,
                  syntaxHighlighting: settings.syntaxHighlighting,
                  onSelect: {
                    navigationState.selectedIndex = index
                    clipboardManager.copyToClipboard(item)
                    settings.playSound()
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                      dismiss(settings.pasteAfterSelecting)
                    }
                  },
                  onDragStart: {
                    DragState.shared.draggedItemId = item.id
                    startDragMonitoringFromDrag()
                  },
                  onDragEnd: {
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                      DragState.shared.draggedItemId = nil
                    }
                  },
                  onCopy: {
                    clipboardManager.copyToClipboard(item)
                  },
                  onPasteAsPlainText: {
                    clipboardManager.copyToClipboardAsPlainText(item)
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                      dismiss(true)
                    }
                  },
                  onDelete: {
                    clipboardManager.deleteItem(item)
                  },
                  onEdit: {
                    navigationState.selectedIndex = index
                    onEditItem?(item)
                  },
                  onPreview: {
                    navigationState.selectedIndex = index
                    let centerX = cardCenterXPositions[index] ?? 0
                    onPreview?(item, index, centerX)
                  },
                  onPinTo: { pinboard in
                    pinboardManager.addItem(item.id, to: pinboard)
                  },
                  pinboards: pinboardManager.pinboards,
                  currentAppName: "Current App"
                )
                .id("\(item.id)-\(index == navigationState.selectedIndex)")
                .background(
                  GeometryReader { geo in
                    Color.clear
                      .onAppear {
                        let frame = geo.frame(in: .global)
                        cardCenterXPositions[index] = frame.midX
                      }
                      .onChange(of: geo.frame(in: .global)) { newFrame in
                        cardCenterXPositions[index] = newFrame.midX
                      }
                  }
                )
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
            .onChange(of: viewMode) { _ in
              // Ensure itemCount is synced when switching between clipboard and pinboard
              navigationState.itemCount = currentItems.count
            }
            .onChange(of: navigationState.selectedIndex) { newIndex in
              if newIndex < currentItems.count {
                let selectedId = "\(currentItems[newIndex].id)-true"
                withAnimation(.easeInOut(duration: 0.2)) {
                  proxy.scrollTo(selectedId)
                }
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
  let quickAccessNumber: Int?  // 1-9 for first 9, 0 for 10th, nil if not in first 10 or command not held
  let holdProgress: Double  // 0...1 for hold-to-edit progress
  var showSourceAppIcons: Bool = true
  var showTimestamps: Bool = true
  var showLinkPreviews: Bool = true
  var syntaxHighlighting: Bool = true
  let onSelect: () -> Void
  var onDragStart: (() -> Void)? = nil
  var onDragEnd: (() -> Void)? = nil
  // Context menu callbacks
  var onCopy: (() -> Void)? = nil
  var onPasteAsPlainText: (() -> Void)? = nil
  var onDelete: (() -> Void)? = nil
  var onEdit: (() -> Void)? = nil
  var onPreview: (() -> Void)? = nil
  var onPinTo: ((Pinboard) -> Void)? = nil
  var pinboards: [Pinboard] = []
  var currentAppName: String = "Application"

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header: type · time on left, tag dots + app icon on right
      HStack(spacing: 5) {
        // Type label + time ago combined
        HStack(spacing: 0) {
          Text(item.typeLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.9))

          if showTimestamps {
            Text(" · " + item.timeAgo)
              .font(.system(size: 10))
              .foregroundStyle(.primary.opacity(0.4))
          }
        }
        .lineLimit(1)

        Spacer(minLength: 4)

        // Detected content tag dots
        ContentTagBadgesRow(tags: item.detectedTags)

        // Source app icon on right (conditional)
        if showSourceAppIcons, let icon = item.sourceApp?.icon {
          Image(nsImage: icon)
            .resizable()
            .frame(width: 16, height: 16)
            .cornerRadius(3)
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(headerBackground)

      // Content area
      ZStack(alignment: .bottomTrailing) {
        contentView
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        // Floating char count for text only
        if item.type == .text {
          Text("\(item.content.count)")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.6))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)
            .padding(8)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(contentBackground)
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(isSelected ? Color.primary.opacity(0.8) : Color.clear, lineWidth: 2)
    )
    .overlay(alignment: .bottomLeading) {
      if let number = quickAccessNumber {
        Text(number == 0 ? "0" : "\(number)")
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundStyle(.primary)
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
            .stroke(Color.primary.opacity(0.2), lineWidth: 3)
            .frame(width: 50, height: 50)

          // Progress ring (fills clockwise)
          Circle()
            .trim(from: 0, to: holdProgress)
            .stroke(
              Color.primary.opacity(0.9),
              style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 50, height: 50)
            .rotationEffect(.degrees(-90))  // Start from top

          // Edit icon in center
          Image(systemName: "pencil")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.primary)
            .opacity(0.7 + holdProgress * 0.3)
        }
      }
    }
    .animation(.easeOut(duration: 0.15), value: quickAccessNumber != nil)
    // Hold-to-edit glow effect (layered for soft bloom) - only for selected card
    .shadow(
      color: Color.primary.opacity(isSelected ? holdProgress * 0.5 : 0),
      radius: isSelected ? 6 * holdProgress : 0
    )
    .shadow(
      color: Color.blue.opacity(isSelected ? holdProgress * 0.3 : 0),
      radius: isSelected ? 10 * holdProgress : 0
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
    .onDrag {
      onDragStart?()
      return createDragItemProvider(with: item.id)
    }
    .onChange(of: DragState.shared.draggedItemId) { newValue in
      if newValue == nil {
        onDragEnd?()
      }
    }
    .contextMenu {
      ItemContextMenu(
        item: item,
        currentAppName: currentAppName,
        pinboards: pinboards,
        onSelect: onSelect,
        onCopy: onCopy,
        onPasteAsPlainText: onPasteAsPlainText,
        onEdit: onEdit,
        onDelete: onDelete,
        onPreview: onPreview,
        onPinTo: onPinTo
      )
    }
  }

  private func createDragItemProvider(with itemId: UUID) -> NSItemProvider {
    // Set global state for drag tracking
    DragState.shared.draggedItemId = itemId

    let provider = NSItemProvider()

    // Register the item ID as a custom type for pinboard drops
    let itemIdString = itemId.uuidString
    provider.registerDataRepresentation(forTypeIdentifier: clipboardItemIDType, visibility: .all) {
      completion in
      completion(itemIdString.data(using: .utf8), nil)
      return nil
    }

    // Also register as plain text with a special prefix as fallback
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.plainText.identifier, visibility: .all
    ) { completion in
      let text = "SUPERCLIP_ITEM_ID:\(itemIdString)"
      completion(text.data(using: .utf8), nil)
      return nil
    }

    switch item.type {
    case .text:
      // For text, provide both plain text and RTF if available
      if let rtfData = item.rtfData {
        provider.registerDataRepresentation(
          forTypeIdentifier: UTType.rtf.identifier, visibility: .all
        ) { completion in
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
          provider.registerFileRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier, fileOptions: [], visibility: .all
          ) { completion in
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

  // MARK: - Dynamic card colors

  /// Header tinted by source app accent color
  private var headerBackground: Color {
    if let accentColor = item.sourceApp?.accentColor {
      return accentColor.opacity(0.18)
    }
    return Color.primary.opacity(0.08)
  }

  /// Content area tinted by content type
  private var contentBackground: Color {
    if item.detectedTags.contains(.color), let parsed = parsedColor {
      return parsed.opacity(0.4)
    }
    switch item.type {
    case .image:
      return Color.primary.opacity(0.02)
    case .url:
      return Color.blue.opacity(0.04)
    case .file:
      return Color.orange.opacity(0.03)
    case .text:
      return Color.primary.opacity(0.04)
    }
  }

  /// Parse the first color value found in the item content
  private var parsedColor: Color? {
    let text = item.content.trimmingCharacters(in: .whitespacesAndNewlines)

    // Hex: #RGB or #RRGGBB
    if let match = text.range(of: #"#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})\b"#, options: .regularExpression) {
      var hex = String(text[match]).dropFirst() // remove #
      if hex.count == 3 {
        hex = hex.map { "\($0)\($0)" }.joined()[...]
      }
      if let val = UInt64(hex, radix: 16) {
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
      }
    }

    // rgb(r, g, b) or rgba(r, g, b, a)
    if let match = text.range(of: #"rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})"#, options: .regularExpression) {
      let sub = String(text[match])
      let nums = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
      if nums.count >= 3 {
        return Color(red: Double(nums[0]) / 255.0, green: Double(nums[1]) / 255.0, blue: Double(nums[2]) / 255.0)
      }
    }

    // hsl(h, s%, l%)
    if let match = text.range(of: #"hsla?\(\s*(\d{1,3})\s*,\s*(\d{1,3})%?\s*,\s*(\d{1,3})%?"#, options: .regularExpression) {
      let sub = String(text[match])
      let nums = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
      if nums.count >= 3 {
        let (r, g, b) = Self.hslToRGB(h: Double(nums[0]), s: Double(nums[1]) / 100.0, l: Double(nums[2]) / 100.0)
        return Color(red: r, green: g, blue: b)
      }
    }

    return nil
  }

  private static func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
    guard s > 0 else { return (l, l, l) }
    let c = (1 - abs(2 * l - 1)) * s
    let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
    let m = l - c / 2
    let (r1, g1, b1): (Double, Double, Double)
    switch h {
    case 0..<60:   (r1, g1, b1) = (c, x, 0)
    case 60..<120:  (r1, g1, b1) = (x, c, 0)
    case 120..<180: (r1, g1, b1) = (0, c, x)
    case 180..<240: (r1, g1, b1) = (0, x, c)
    case 240..<300: (r1, g1, b1) = (x, 0, c)
    default:        (r1, g1, b1) = (c, 0, x)
    }
    return (r1 + m, g1 + m, b1 + m)
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
      } else if syntaxHighlighting, let highlighted = SyntaxHighlighter.highlight(item.content) {
        // Display syntax-highlighted code preview
        RichTextCardPreview(attributedString: highlighted)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(10)
      } else {
        Text(item.content)
          .font(.system(size: 13))
          .foregroundStyle(.primary.opacity(0.85))
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
  private static let imageExtensions = [
    "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif",
  ]

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
                  .font(.system(size: 12))
                  .foregroundStyle(.primary.opacity(0.85))
                  .lineLimit(1)
                  .truncationMode(.middle)
              }
            }

            if urls.count > 4 {
              Text("+ \(urls.count - 4) more...")
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.45))
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
        .font(.system(size: 12))
        .foregroundStyle(.primary.opacity(0.85))
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
          .foregroundStyle(.primary)
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
      if showLinkPreviews, let metadata = item.linkMetadata, let image = metadata.image {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
      } else if showLinkPreviews, let metadata = item.linkMetadata, let icon = metadata.icon {
        // Favicon / site icon fallback
        VStack(spacing: 6) {
          Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 36, height: 36)
            .cornerRadius(6)
          Text(metadata.displayURL)
            .font(.system(size: 10))
            .foregroundStyle(.primary.opacity(0.3))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue.opacity(0.04))
      } else {
        // Placeholder with link symbol
        VStack(spacing: 6) {
          Image(systemName: "link.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(.blue.opacity(0.35))
          if let displayURL = item.linkMetadata?.displayURL {
            Text(displayURL)
              .font(.system(size: 10))
              .foregroundStyle(.primary.opacity(0.3))
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue.opacity(0.04))
      }

      // Footer with title and URL
      VStack(alignment: .leading, spacing: 3) {
        if let metadata = item.linkMetadata, let title = metadata.title, !title.isEmpty {
          Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary.opacity(0.9))
            .lineLimit(1)
        }

        Text(item.linkMetadata?.displayURL ?? item.content)
          .font(.system(size: 11))
          .foregroundStyle(.blue.opacity(0.55))
          .lineLimit(1)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.blue.opacity(0.06))
    }
  }
}

// MARK: - Item Context Menu

struct ItemContextMenu: View {
  let item: ClipboardItem
  let currentAppName: String
  let pinboards: [Pinboard]
  let onSelect: () -> Void
  var onCopy: (() -> Void)?
  var onPasteAsPlainText: (() -> Void)?
  var onEdit: (() -> Void)?
  var onDelete: (() -> Void)?
  var onPreview: (() -> Void)?
  var onPinTo: ((Pinboard) -> Void)?

  var body: some View {
    // Paste to current app
    Button {
      onSelect()
    } label: {
      Text("Paste to \(currentAppName)")
    }
    .keyboardShortcut(.return, modifiers: [])

    // Paste as Plain Text
    Button {
      onPasteAsPlainText?()
    } label: {
      Text("Paste as Plain Text")
    }
    .keyboardShortcut(.return, modifiers: .shift)

    // Copy
    Button {
      onCopy?()
    } label: {
      Text("Copy")
    }
    .keyboardShortcut("c", modifiers: .command)

    Divider()

    // Preview
    Button {
      onPreview?()
    } label: {
      Text("Preview")
    }
    .keyboardShortcut(.space, modifiers: [])

    // Edit (hold space) - only for text/url
    if item.type == .text || item.type == .url {
      Button {
        onEdit?()
      } label: {
        Text("Edit — hold ␣")
      }
    }

    // Writing Tools (not implemented)
    Menu {
      Text("Coming soon")
    } label: {
      Label("Writing Tools", systemImage: "pencil.and.outline")
    }

    // Rename (not implemented)
    Button {
      // TODO: Implement rename
    } label: {
      Text("Rename")
    }
    .keyboardShortcut("r", modifiers: .command)
    .disabled(true)

    // Delete
    Button(role: .destructive) {
      onDelete?()
    } label: {
      Text("Delete")
    }
    .keyboardShortcut(.delete, modifiers: [])

    // Quick Actions submenu (context-aware)
    QuickActionsContextMenu(item: item)

    Divider()

    // Pin submenu
    Menu {
      ForEach(pinboards) { pinboard in
        Button {
          onPinTo?(pinboard)
        } label: {
          Label {
            Text(pinboard.name)
          } icon: {
            Image(systemName: "circle.fill")
              .symbolRenderingMode(.monochrome)
              .foregroundStyle(pinboard.color.color)
          }
        }
      }
      if pinboards.isEmpty {
        Text("No pinboards")
      }
    } label: {
      Label("Pin", systemImage: "pin")
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
          .foregroundStyle(.primary.opacity(0.9))
          .shadow(color: .black.opacity(0.3), radius: 4)

        Text("VIDEO")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.8))
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
        let image = NSImage(
          cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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

// MARK: - Filter Pill Button

struct FilterPillButton: View {
  let tag: FilterTag
  let isSelected: Bool
  let onSelect: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 4) {
        Image(systemName: tag.icon)
          .font(.system(size: 10))
        Text(tag.rawValue)
          .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
      }
      .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.primary.opacity(0.6)))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        isSelected
          ? Color.primary.opacity(0.18)
          : (isHovered ? Color.primary.opacity(0.1) : Color.primary.opacity(0.05))
      )
      .cornerRadius(14)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

// MARK: - Content Tag Badge

struct ContentTagBadge: View {
  let tag: ContentTag

  var label: String {
    switch tag {
    case .color: return "Color"
    case .email: return "Email"
    case .phone: return "Phone"
    case .code: return "Code"
    case .json: return "JSON"
    case .address: return "Addr"
    }
  }

  var icon: String {
    switch tag {
    case .color: return "paintpalette.fill"
    case .email: return "envelope.fill"
    case .phone: return "phone.fill"
    case .code: return "chevron.left.forwardslash.chevron.right"
    case .json: return "curlybraces"
    case .address: return "mappin"
    }
  }

  var badgeColor: Color {
    switch tag {
    case .color: return .purple
    case .email: return .blue
    case .phone: return .green
    case .code: return .orange
    case .json: return .yellow
    case .address: return .cyan
    }
  }

  var body: some View {
    Image(systemName: icon)
      .font(.system(size: 8, weight: .semibold))
      .foregroundStyle(badgeColor)
      .frame(width: 16, height: 16)
      .background(badgeColor.opacity(0.15))
      .cornerRadius(4)
      .help(label)
  }
}

// MARK: - Content Tag Badges Row

struct ContentTagBadgesRow: View {
  let tags: Set<ContentTag>

  var body: some View {
    if !tags.isEmpty {
      HStack(spacing: 2) {
        ForEach(tags.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { tag in
          ContentTagBadge(tag: tag)
        }
      }
    }
  }
}

struct HeaderIconButton: View {
  let icon: String
  let action: () -> Void
  var helpText: String? = nil

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 15))
        .foregroundStyle(.primary.opacity(0.85))
        .frame(width: 32, height: 32)
        .background(isHovered ? Color.primary.opacity(0.12) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
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
  var itemCount: Int? = nil
  let onSelect: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: onSelect) {
      if isCompact {
        HStack(spacing: 5) {
          Image(systemName: "sparkle.text.clipboard")
            .font(.system(size: 12))
            .foregroundStyle(.primary)
          if let count = itemCount {
            Text("\(count)")
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(.primary.opacity(0.6))
          }
        }
        .frame(minWidth: 28, minHeight: 28)
        .padding(.horizontal, 6)
        .background(
          isSelected
            ? Color.primary.opacity(0.18) : (isHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
        .cornerRadius(8)
      } else {
        HStack(spacing: 7) {
          Image(systemName: "sparkle.text.clipboard")
            .font(.system(size: 12))
            .foregroundStyle(.primary)
          Text("Clipboard")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
          if let count = itemCount {
            Text("\(count)")
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(.primary.opacity(0.5))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.primary.opacity(0.1))
              .cornerRadius(4)
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
          isSelected
            ? Color.primary.opacity(0.18) : (isHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
        .cornerRadius(10)
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
  var itemCount: Int? = nil
  let onSelect: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void
  let onColorChange: (PinboardColor) -> Void
  let onDrop: (UUID) -> Void

  @State private var isDragOver = false
  @State private var isHovered = false
  @ObservedObject private var dragState = DragState.shared

  private var backgroundColor: Color {
    if isDragOver {
      return Color.primary.opacity(0.4)
    } else if dragState.draggedItemId != nil {
      return Color.primary.opacity(0.2)
    } else if isSelected {
      return Color.primary.opacity(0.15)
    } else if isHovered {
      return Color.primary.opacity(0.1)
    } else {
      return Color.clear
    }
  }

  var body: some View {
    Group {
      if isCompact {
        HStack(spacing: 4) {
          Circle()
            .fill(pinboard.color.color)
            .frame(width: 9, height: 9)
          if let count = itemCount {
            Text("\(count)")
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(.primary.opacity(0.6))
          }
        }
        .padding(10)
        .background(backgroundColor)
        .cornerRadius(8)
      } else {
        HStack(spacing: 7) {
          Circle()
            .fill(pinboard.color.color)
            .frame(width: 8, height: 8)
          Text(pinboard.name)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary.opacity(0.9))
          if let count = itemCount {
            Text("\(count)")
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(.primary.opacity(0.5))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.primary.opacity(0.1))
              .cornerRadius(4)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(backgroundColor)
        .cornerRadius(10)
      }
    }
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovered = hovering
    }
    .onTapGesture(count: 2) {
      onEdit()
    }
    .onTapGesture(count: 1) {
      onSelect()
    }
    .onDrop(
      of: [
        clipboardItemIDType, UTType.plainText.identifier, UTType.image.identifier,
        UTType.fileURL.identifier, UTType.url.identifier,
      ], isTargeted: $isDragOver
    ) { providers in
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
            let itemId = UUID(uuidString: itemIdString)
          else {
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
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) {
          data, error in
          guard let data = data,
            let text = String(data: data, encoding: .utf8),
            text.hasPrefix("SUPERCLIP_ITEM_ID:")
          else {
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
      Button("Rename") {
        onEdit()
      }

      Divider()
      PinboardColorPicker(currentColor: pinboard.color, onColorChange: onColorChange)
      Divider()
      Button(role: .destructive) {
        onDelete()
      } label: {
        Text("Delete \(pinboard.name)")
          .foregroundStyle(.red)
      }
    }
  }
}

struct PinboardColorPicker: View {
  let currentColor: PinboardColor
  let onColorChange: (PinboardColor) -> Void

  private let colors = PinboardColor.allCases
  private let colorsPerRow = 4

  var body: some View {
    VStack(spacing: 4) {
      ForEach(0..<2, id: \.self) { row in
        ControlGroup {
          ForEach(0..<colorsPerRow, id: \.self) { col in
            let index = row * colorsPerRow + col
            if index < colors.count {
              Button {
                onColorChange(colors[index])
              } label: {
                Image(
                  systemName: currentColor == colors[index]
                    ? "smallcircle.filled.circle.fill" : "circle.fill"
                )
                .symbolRenderingMode(.monochrome)
              }
              .tint(colors[index].color)
            }
          }
        }
        .controlGroupStyle(.palette)
      }
    }
  }
}

struct PinboardEditView: View {
  @Binding var name: String
  let color: PinboardColor
  @FocusState.Binding var isFocused: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color.color)
        .frame(width: 6, height: 6)

      TextField("Untitled", text: $name)
        .textFieldStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(.primary)
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
    .background(Color.primary.opacity(0.15))
    .cornerRadius(6)
    .onAppear {
      isFocused = true
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
