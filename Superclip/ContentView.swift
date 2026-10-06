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
  var onResize: ((CGFloat) -> Void)?  // Called to resize the drawer panel
  var onEditItem: ((ClipboardItem) -> Void)?  // Called to open rich text editor for an item
  var onOpenSettings: (() -> Void)?  // Called to open settings window

  @FocusState private var isSearchFocused: Bool
  @State private var searchText: String = ""
  @State private var showSearchField: Bool = false
  @State private var viewMode: ViewMode = .clipboard
  @State private var selectedFilter: FilterTag = .all
  @State private var editingPinboard: Pinboard?
  @State private var editingPinboardName: String = ""
  @State private var editingPinboardColor: PinboardColor = .red
  @FocusState private var isEditingPinboard: Bool
  @State private var dragLocation: CGPoint? = nil
  @State private var dragMonitorTimer: Timer? = nil
  @State private var dragMouseUpMonitor: Any? = nil
  /// index -> card center X in screen coords. A plain reference box, not view
  /// state: every visible card writes here on every scroll frame, and nothing
  /// needs to re-render when it changes.
  @State private var cardPositions = CardPositions()
  /// Memo for `currentItems` (see there).
  @State private var itemsCache = VisibleItemsCache()
  @State private var previewUpdateWorkItem: DispatchWorkItem? = nil
  @State private var toastText: String?
  @State private var toastWorkItem: DispatchWorkItem?

  /// Name of the app a paste will land in. The drawer is a non-activating
  /// panel, so the user's app is still frontmost while it is open.
  private let pasteTargetName: String = {
    guard let app = NSWorkspace.shared.frontmostApplication,
      app.bundleIdentifier != Bundle.main.bundleIdentifier
    else { return "" }
    return app.localizedName ?? ""
  }()

  /// The cards currently shown: history, or a pinboard, narrowed by search.
  ///
  /// This is read many times per render (count checks, selection, the list
  /// itself) and each read used to re-filter or re-search the whole history,
  /// so one keystroke in search ran well over a dozen full searches. The
  /// result is now computed once and reused until one of its inputs changes.
  var currentItems: [ClipboardItem] {
    let key = VisibleItemsCache.Key(
      historyVersion: clipboardManager.historyVersion,
      query: searchText,
      filter: selectedFilter,
      pinboardId: { if case .pinboard(let p) = viewMode { return p.id } else { return nil } }(),
      pinboards: pinboardManager.pinboards
    )
    if itemsCache.key == key { return itemsCache.items }
    let unfiltered = computeCurrentItems()
    let items = selectedFilter == .all ? unfiltered : unfiltered.filter(selectedFilter.matches)
    itemsCache.key = key
    itemsCache.items = items
    return items
  }

  private func computeCurrentItems() -> [ClipboardItem] {
    switch viewMode {
    case .clipboard:
      return filteredHistory
    case .pinboard(let pinboard):
      // viewMode holds a snapshot of the pinboard; membership has to come from
      // the live one or pin/unpin never shows up while the board is open.
      let live = pinboardManager.pinboards.first(where: { $0.id == pinboard.id }) ?? pinboard
      let pinboardItems = pinboardManager.getItems(for: live, from: clipboardManager.history)
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

      // Type filters, shown while searching (and for as long as one is active)
      if showSearchField || selectedFilter != .all {
        filterBarView
          .transition(.opacity)
      }

      // Clipboard history list
      itemsListView

      // What the keys do, right where the hands already are. Every action
      // here used to be discoverable only from the tutorial or the menus.
      if settings.showKeyboardHints {
        KeyHintBar(hints: keyHints, trailing: showSearchField ? nil : "Type to search")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Brand.white)
    .clipShape(Rectangle())
    .overlay(alignment: .top) {
      // Hairline top edge: the drawer has no shadow, and in dark mode a
      // near-black surface over a dark window had no visible boundary
      Rectangle().fill(Brand.gray300).frame(height: 1).allowsHitTesting(false)
    }
    .overlay(alignment: .bottom) {
      if let toastText = toastText {
        Text(toastText)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Brand.white)
          .padding(.horizontal, 14)
          .padding(.vertical, 7)
          .background(Brand.black)
          .padding(.bottom, settings.showKeyboardHints ? 46 : 22)
          .transition(.opacity.combined(with: .move(edge: .bottom)))
          .allowsHitTesting(false)
          .accessibilityAddTraits(.updatesFrequently)
      }
    }
    .overlay(alignment: .top) {
      // Invisible resize edge at the top — cursor changes on hover, drag to resize
      Rectangle()
        .fill(Color.clear)
        .frame(height: 6)
        .contentShape(Rectangle())
        .onHover { hovering in
          if hovering {
            NSCursor.resizeUpDown.push()
          } else {
            NSCursor.pop()
          }
        }
        .gesture(
          DragGesture()
            .onChanged { _ in
              // Use absolute mouse position to avoid jank from view resizing during drag
              if let screen = NSScreen.main {
                let newHeight = NSEvent.mouseLocation.y - screen.visibleFrame.minY
                onResize?(newHeight)
              }
            }
        )
    }
    .background(
      // Invisible overlay to detect drag outside
      GeometryReader { geometry in
        Color.clear
          .onChange(of: DragState.shared.draggedItemId) { itemId in
            if itemId != nil {
              // Start monitoring mouse location when drag starts
              // Get frame in screen coordinates
              DispatchQueue.main.async {
                startDragMonitoring()
              }
            } else {
              // Stop monitoring when drag ends
              stopDragMonitoring()
            }
          }
          .onAppear {
            // Also monitor when view appears in case drag is already active
            if DragState.shared.draggedItemId != nil {
              startDragMonitoring()
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
      if shouldSelect {
        // Always clear the flag: left set (e.g. Return on an empty list) it
        // would swallow every later Return, since onChange never fires again.
        navigationState.shouldSelectAndDismiss = false
        guard let item = selectedItem else { return }
        clipboardManager.copyToClipboard(item)
        settings.playSound()
        DispatchQueue.main.asyncAfter(deadline: .now()) {
          dismiss(settings.pasteAfterSelecting)
        }
      }
    }
    .onChange(of: navigationState.shouldPastePlainAndDismiss) { shouldPaste in
      if shouldPaste {
        navigationState.shouldPastePlainAndDismiss = false
        guard let item = selectedItem else { return }
        copyPlain(item)
        settings.playSound()
        DispatchQueue.main.asyncAfter(deadline: .now()) {
          dismiss(settings.pasteAfterSelecting)
        }
      }
    }
    .onChange(of: navigationState.shouldCopyCurrent) { shouldCopy in
      if shouldCopy {
        navigationState.shouldCopyCurrent = false
        guard let item = selectedItem else { return }
        clipboardManager.copyToClipboard(item)
        settings.playSound()
        showToast("Copied")
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
    .onChange(of: selectedFilter) { _ in
      if navigationState.selectedIndex != 0 { navigationState.selectedIndex = 0 }
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
        // Esc clears the type filter along with the search. (Arrowing into
        // the results closes an empty search field but keeps the filter.)
        selectedFilter = .all
      }
    }
    .onChange(of: navigationState.shouldShowPreview) { shouldShow in
      if shouldShow {
        navigationState.shouldShowPreview = false
        guard let item = selectedItem else { return }
        let centerX = cardPositions.centerX[navigationState.selectedIndex] ?? 0
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
    // Publish the selected item's identity for AppDelegate flows (hold-Space
    // editing). selectedIndex alone is ambiguous: it indexes the filtered/
    // pinboard list, not clipboardManager.history.
    .onChange(of: selectedItem?.id) { newId in
      navigationState.selectedItemId = newId
    }
    .onChange(of: navigationState.shouldDeleteCurrent) { shouldDelete in
      if shouldDelete {
        navigationState.shouldDeleteCurrent = false
        guard let item = selectedItem else { return }
        if case .pinboard(let pinboard) = viewMode {
          // Inside a pinboard, Backspace takes the clip off the board. It
          // stays in history; deleting it outright would be a surprise here.
          pinboardManager.removeItem(item.id, from: pinboard)
          showToast("Removed from \(pinboard.name)")
          if navigationState.selectedIndex >= currentItems.count {
            navigationState.selectedIndex = max(0, currentItems.count - 1)
          }
        } else {
          deleteWithFeedback(item)
          // Adjust selection if needed (the removal itself lands on the next runloop turn)
          if navigationState.selectedIndex >= currentItems.count - 1 {
            navigationState.selectedIndex = max(0, currentItems.count - 2)
          }
        }
      }
    }
    .onChange(of: viewMode) { _ in
      // @Published does not de-duplicate: writing 0 over 0 still re-renders
      if navigationState.selectedIndex != 0 { navigationState.selectedIndex = 0 }
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

  private func startDragMonitoring() {
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

  /// Hints for the current mode: searching, inside a pinboard, or browsing.
  private var keyHints: [KeyHint] {
    if showSearchField {
      return [
        KeyHint(keys: "\u{2190}\u{2192}", label: "Browse results"),
        KeyHint(keys: "\u{21A9}", label: "Paste"),
        KeyHint(keys: "esc", label: "Clear search"),
      ]
    }
    var hints = [
      KeyHint(keys: "\u{21A9}", label: "Paste"),
      KeyHint(keys: "\u{21E7}\u{21A9}", label: "Plain text"),
      KeyHint(keys: "\u{2318}C", label: "Copy"),
      KeyHint(keys: "space", label: "Preview"),
      KeyHint(keys: "hold space", label: "Edit"),
    ]
    if case .pinboard = viewMode {
      hints.append(KeyHint(keys: "\u{232B}", label: "Unpin"))
    } else {
      hints.append(KeyHint(keys: "\u{232B}", label: "Delete"))
    }
    if !pinboardManager.pinboards.isEmpty {
      hints.append(KeyHint(keys: "\u{2318}\u{2190}\u{2192}", label: "Pinboards"))
    }
    return hints
  }

  // MARK: - Feedback

  /// Brief confirmation at the bottom of the drawer for actions that
  /// otherwise change nothing visible (copy, pin, delete).
  private func showToast(_ text: String) {
    toastWorkItem?.cancel()
    withAnimation(.easeOut(duration: 0.15)) { toastText = text }
    let work = DispatchWorkItem {
      withAnimation(.easeIn(duration: 0.2)) { toastText = nil }
    }
    toastWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
  }

  private func deleteWithFeedback(_ item: ClipboardItem) {
    clipboardManager.deleteItem(item)
    showToast("Deleted \u{00B7} \u{2318}Z to undo")
  }

  /// Plain-text copy only means something for text; other types copy as they are.
  private func copyPlain(_ item: ClipboardItem) {
    if item.type == .text || item.type == .url {
      clipboardManager.copyToClipboardAsPlainText(item)
    } else {
      clipboardManager.copyToClipboard(item)
    }
  }

  private func updateNavigationForCurrentItems() {
    navigationState.itemCount = currentItems.count
    if navigationState.selectedIndex >= currentItems.count && currentItems.count > 0 {
      navigationState.selectedIndex = 0
    }
  }

  private func updatePreviewForIndex(_ index: Int, attempt: Int) {
    // Cancel any previously queued preview update to avoid piling up work during rapid navigation
    previewUpdateWorkItem?.cancel()

    let delay: Double = attempt == 1 ? 0.05 : 0.15
    let workItem = DispatchWorkItem { [self] in
      guard navigationState.isPreviewVisible,
        index == navigationState.selectedIndex,
        index < currentItems.count
      else { return }

      let item = currentItems[index]
      let centerX = cardPositions.centerX[index] ?? 0

      if centerX > 0 {
        onPreview?(item, index, centerX)
      } else if attempt < 3 {
        // Retry if position not ready yet
        updatePreviewForIndex(index, attempt: attempt + 1)
      }
    }
    previewUpdateWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
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
              .foregroundStyle(.primary.opacity(0.6))
            TextField("Search...", text: $searchText)
              .textFieldStyle(.plain)
              .font(.system(size: 14))
              .foregroundStyle(.primary)
              .focused($isSearchFocused)
              .onChange(of: searchText) { _ in
                if navigationState.selectedIndex != 0 { navigationState.selectedIndex = 0 }
              }

            if !searchText.isEmpty {
              Button {
                searchText = ""
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 12))
                  .foregroundStyle(.primary.opacity(0.6))
              }
              .buttonStyle(.plain)
            }

          }
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .background(Brand.gray100)
          .frame(width: 220)
        } else {
          HeaderIconButton(
            icon: "magnifyingglass",
            action: {
              showSearchField = true
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
              }
            }, helpText: "Search (or just start typing)")
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

        // Pinboard tabs. With more boards than fit, they scroll sideways
        // instead of wrapping to two lines and running under the settings button.
        ViewThatFits(in: .horizontal) {
          HStack(spacing: showSearchField ? 8 : 16) { pinboardTabs }
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: showSearchField ? 8 : 16) { pinboardTabs }
          }
        }

        // Add pinboard button (hide when searching)
        if !showSearchField {
          HeaderIconButton(
            icon: "plus",
            action: {
              let newPinboard = pinboardManager.createPinboard(name: "Untitled", color: .red)
              editingPinboard = newPinboard
              editingPinboardName = "Untitled"
              editingPinboardColor = .red
              isEditingPinboard = true
              onEditingPinboardChanged?(true)
              viewMode = .pinboard(newPinboard)
            }, helpText: "New pinboard")
        }

        // Text sniper button (always visible)
        HeaderIconButton(
          icon: "text.viewfinder",
          action: {
            onTextSnipe?()
          }, helpText: "Text Sniper (Cmd+Shift+`)")
      }
      .padding(.horizontal, 52)

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

  @ViewBuilder
  private var pinboardTabs: some View {
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
          itemCount: settings.showItemCount ? pinboard.itemIds.count : nil,
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
            showToast("Pinned to \(pinboard.name)")
          }
        )
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
      .padding(.top, 8)
      .padding(.bottom, 2)
      // Centre the pills when they fit; scroll when they don't
      .frame(maxWidth: .infinity)
    }
  }

  // MARK: - Items List View

  var itemsListView: some View {
    Group {
      if currentItems.isEmpty {
        VStack(spacing: 10) {
          Image(systemName: emptyStateIcon)
            .font(.system(size: 34, weight: .light))
            .foregroundStyle(.primary.opacity(0.45))

          Text(emptyStateMessage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Brand.gray600)

          if let hint = emptyStateHint {
            Text(hint)
              .font(.system(size: 12))
              .foregroundStyle(Brand.gray500)
              .multilineTextAlignment(.center)
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
                  hold: navigationState.hold,
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
                    startDragMonitoring()
                  },
                  onDragEnd: {
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                      DragState.shared.draggedItemId = nil
                    }
                  },
                  onCopy: {
                    clipboardManager.copyToClipboard(item)
                    showToast("Copied")
                  },
                  onPasteAsPlainText: {
                    copyPlain(item)
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                      dismiss(settings.pasteAfterSelecting)
                    }
                  },
                  onDelete: {
                    deleteWithFeedback(item)
                  },
                  onEdit: {
                    navigationState.selectedIndex = index
                    onEditItem?(item)
                  },
                  onPreview: {
                    navigationState.selectedIndex = index
                    let centerX = cardPositions.centerX[index] ?? 0
                    onPreview?(item, index, centerX)
                  },
                  onPinTo: { pinboard in
                    pinboardManager.addItem(item.id, to: pinboard)
                    showToast("Pinned to \(pinboard.name)")
                  },
                  onUnpinFrom: { pinboard in
                    pinboardManager.removeItem(item.id, from: pinboard)
                    showToast("Removed from \(pinboard.name)")
                  },
                  pinboards: pinboardManager.pinboards,
                  currentAppName: pasteTargetName
                )
                .equatable()
                .id(item.id)
                .onAppear {
                  if item.type == .url {
                    clipboardManager.ensureLinkMetadata(item)
                  }
                }
                .background(
                  GeometryReader { geo in
                    Color.clear
                      .onAppear {
                        cardPositions.centerX[index] = geo.frame(in: .global).midX
                      }
                      .onChange(of: geo.frame(in: .global)) { newFrame in
                        cardPositions.centerX[index] = newFrame.midX
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
              navigationState.selectedItemId = selectedItem?.id
            }
            .onChange(of: currentItems.count) { newCount in
              navigationState.itemCount = newCount
            }
            .onChange(of: viewMode) { _ in
              navigationState.itemCount = currentItems.count
            }
            .onChange(of: navigationState.selectedIndex) { newIndex in
              if newIndex < currentItems.count {
                proxy.scrollTo(currentItems[newIndex].id)
              }
            }
          }
        }
      }
    }
  }

  var emptyStateMessage: String {
    if !searchText.isEmpty { return "No results for \u{201C}\(searchText)\u{201D}" }
    if selectedFilter != .all { return "No \(selectedFilter.rawValue.lowercased()) here" }
    switch viewMode {
    case .clipboard:
      return "No clipboard history yet"
    case .pinboard:
      return "This pinboard is empty"
    }
  }

  private var emptyStateIcon: String {
    if !searchText.isEmpty { return "magnifyingglass" }
    if selectedFilter != .all { return selectedFilter.icon }
    switch viewMode {
    case .clipboard: return settings.monitorClipboard ? "doc.on.clipboard" : "pause.circle"
    case .pinboard: return "pin"
    }
  }

  private var emptyStateHint: String? {
    if !searchText.isEmpty { return "Press Esc to clear the search" }
    if selectedFilter != .all { return "Choose All to see everything" }
    switch viewMode {
    case .clipboard:
      return settings.monitorClipboard
        ? "Copy something to get started"
        : "Clipboard monitoring is paused. Turn it back on from the menu bar or Settings."
    case .pinboard:
      return "Drag a card onto this tab, or right-click a card and choose Pin"
    }
  }

}

struct ClipboardItemCard: View, Equatable {
  nonisolated static func == (lhs: ClipboardItemCard, rhs: ClipboardItemCard) -> Bool {
    lhs.item == rhs.item &&
    lhs.index == rhs.index &&
    lhs.isSelected == rhs.isSelected &&
    lhs.quickAccessNumber == rhs.quickAccessNumber &&
    lhs.showSourceAppIcons == rhs.showSourceAppIcons &&
    lhs.showTimestamps == rhs.showTimestamps &&
    lhs.showLinkPreviews == rhs.showLinkPreviews &&
    lhs.syntaxHighlighting == rhs.syntaxHighlighting &&
    lhs.currentAppName == rhs.currentAppName &&
    lhs.pinboards == rhs.pinboards
  }

  let item: ClipboardItem
  let index: Int
  let isSelected: Bool
  let quickAccessNumber: Int?  // 1-9 for first 9, 0 for 10th, nil if not in first 10 or command not held
  /// Hold-to-edit progress. Passed by reference and observed only by the
  /// ring overlay, so a hold animates without re-rendering any card.
  let hold: HoldProgress
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
  var onUnpinFrom: ((Pinboard) -> Void)? = nil
  var pinboards: [Pinboard] = []
  /// App the paste will land in; empty when unknown
  var currentAppName: String = ""

  /// One spoken line for the card: what it is, where it came from, what it says.
  private var accessibilitySummary: String {
    var parts = [item.typeLabel]
    if let app = item.sourceApp?.name { parts.append("from \(app)") }
    switch item.type {
    case .image: parts.append(item.imageDimensions ?? "image")
    case .file: parts.append(item.content)
    default: parts.append(String(cardText.prefix(140)))
    }
    return parts.joined(separator: ", ")
  }

  private var memberPinboards: [Pinboard] {
    pinboards.filter { $0.itemIds.contains(item.id) }
  }

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
              .foregroundStyle(Brand.gray500)
          }
        }
        .lineLimit(1)

        Spacer(minLength: 4)

        // Pinboard membership dots (in the header row so they never sit on
        // top of the app icon or the tag badges)
        if !memberPinboards.isEmpty {
          HStack(spacing: 3) {
            ForEach(memberPinboards) { pinboard in
              Circle()
                .fill(pinboard.color.color)
                .frame(width: 7, height: 7)
            }
          }
          .help("Pinned to " + memberPinboards.map(\.name).joined(separator: ", "))
        }

        // Detected content tag dots
        ContentTagBadgesRow(tags: item.detectedTags)

        // Source app icon on right (conditional)
        if showSourceAppIcons, let icon = item.sourceApp?.icon {
          Image(nsImage: icon)
            .resizable()
            .frame(width: 16, height: 16)
            .clipShape(Rectangle())
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(headerBackground)
      .overlay(alignment: .top) {
        // Paste-style semantic accent: content type at a glance
        Rectangle().fill(typeAccent).frame(height: 2)
      }

      // Content area
      ZStack(alignment: .bottomTrailing) {
        contentView
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        // Floating metadata pill (Paste-style): chars / dimensions / file count
        if let metadata = metadataLabel {
          Text(metadata)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Brand.gray600)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Brand.gray200)
            .padding(8)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(contentBackground)
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(Rectangle())
    .overlay(
      // Inset 2pt when selected: a 1pt line disappears against image edges
      Rectangle()
        .strokeBorder(isSelected ? Brand.black : Brand.gray200, lineWidth: isSelected ? 2 : 1)
    )
    .overlay(alignment: .bottomLeading) {
      if let number = quickAccessNumber {
        Text(number == 0 ? "0" : "\(number)")
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundStyle(Brand.white)
          .frame(width: 20, height: 20)
          .background(Brand.black)
          .padding(6)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .overlay {
      // Hold-to-edit progress ring (only for editable items when selected and holding)
      if isSelected && (item.type == .text || item.type == .url) {
        HoldRingOverlay(hold: hold)
      }
    }
    .animation(.easeOut(duration: 0.15), value: quickAccessNumber != nil)
    .animation(.easeOut(duration: 0.15), value: isSelected)
    .contentShape(Rectangle())
    .onTapGesture {
      onSelect()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
    .accessibilityHint("Pastes this clip")
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { onSelect() }
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
        onPinTo: onPinTo,
        onUnpinFrom: onUnpinFrom
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

    // (No plain-text copy of the ID: registered ahead of the real content it
    // is what other apps received, so dragging a card into a document
    // dropped "SUPERCLIP_ITEM_ID:..." instead of the clip.)

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
      // Offer the compressed bytes, so a card dragged to the desktop or into
      // another app arrives as a PNG rather than an uncompressed TIFF
      if let stored = ImageStore.shared.loadData(for: item.id) ?? item.imageData,
        let representation = ClipboardManager.compactImageRepresentation(of: stored)
      {
        let typeIdentifier = representation.type == .png ? UTType.png.identifier : UTType.jpeg.identifier
        provider.suggestedName = "Superclip Image"
        provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier, visibility: .all) { completion in
          completion(representation.data, nil)
          return nil
        }
      } else if let nsImage = item.nsImage {
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

  /// Bottom-trailing metadata pill text, varies by type
  private var metadataLabel: String? {
    switch item.type {
    case .text:
      // A character count says nothing useful about a colour swatch
      if cardColor != nil { return nil }
      return "\(item.content.count)"
    case .image:
      return item.imageDimensions
    case .file:
      if let urls = item.fileURLs, urls.count > 1 { return "\(urls.count) files" }
      return nil
    case .url:
      return nil
    }
  }

  /// Header background, faintly tinted by the content-type accent
  private var headerBackground: some View {
    ZStack {
      Brand.gray100
      typeAccent.opacity(0.07)
    }
  }

  /// Semantic accent per content type (muted, adapts to light/dark).
  private var typeAccent: Color {
    switch item.type {
    case .text: return Color(nsColor: .systemOrange)
    case .url: return Color(nsColor: .systemBlue)
    case .image: return Color(nsColor: .systemPink)
    case .file: return Color(nsColor: .systemPurple)
    }
  }

  /// The colour this card represents, when the whole clip is one colour value.
  /// Clips that merely contain a colour (a stylesheet, "Fixes #123") get no fill.
  private var cardColor: ContentDetector.RGB? {
    guard item.type == .text, item.detectedTags.contains(.color) else { return nil }
    return ContentDetector.singleColor(in: item.content)
  }

  /// Content area background
  private var contentBackground: Color {
    if let c = cardColor {
      return Color(red: c.r, green: c.g, blue: c.b)
    }
    return Brand.white
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

  /// What the card shows: the clip without surrounding blank space (clips are
  /// stored exactly as copied), cut to what could ever fit. Handing SwiftUI a
  /// megabyte of pasted log for an eight-line card made that card slow every
  /// time it was laid out.
  private var cardText: String {
    let limit = 1_500
    let head = item.content.utf16.count > limit ? String(item.content.prefix(limit)) : item.content
    return head.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var textContentView: some View {
    Group {
      if let c = cardColor {
        // Colour swatch card: the fill is the real colour, so the label
        // colour is picked from its brightness rather than the app theme.
        Text(item.content.trimmingCharacters(in: .whitespacesAndNewlines))
          .font(.system(size: 14, weight: .semibold, design: .monospaced))
          .foregroundStyle(c.prefersDarkText ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
          .lineLimit(2)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(10)
      } else if let attributedString = item.attributedString {
        // Display rich text preview
        RichTextCardPreview(attributedString: attributedString)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(10)
      } else if syntaxHighlighting, let highlighted = SyntaxHighlighter.highlight(cardText) {
        // Display syntax-highlighted code preview
        RichTextCardPreview(attributedString: highlighted)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(10)
      } else {
        Text(cardText)
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
    ClipThumbnailView(item: item)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
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
          if isImageFile(url) {
            FileImageThumbnailView(url: url)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if isVideoFile(url) {
            VideoThumbnailView(url: url)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if isAudioFile(url) {
            AudioFileThumbnailView(url: url)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .foregroundStyle(Brand.gray500)
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
    if isImageFile(url) {
      // System file icon — decoding the actual image at full resolution for
      // a 20×20 badge re-ran on every body evaluation of the card.
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 20, height: 20)
        .clipped()
    } else if isVideoFile(url) {
      ZStack {
        Rectangle()
          .fill(Brand.gray200)
          .frame(width: 20, height: 20)
        Image(systemName: "play.fill")
          .font(.system(size: 8))
          .foregroundStyle(.primary)
      }
    } else if isAudioFile(url) {
      ZStack {
        Rectangle()
          .fill(Brand.gray200)
          .frame(width: 20, height: 20)
        Image(systemName: "waveform")
          .font(.system(size: 10))
          .foregroundStyle(Brand.gray600)
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
          Text(metadata.displayURL)
            .font(.system(size: 10))
            .foregroundStyle(Brand.gray500)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.gray100)
      } else {
        // Placeholder with link symbol
        VStack(spacing: 6) {
          Image(systemName: "link.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(Brand.gray500)
          if let displayURL = item.linkMetadata?.displayURL {
            Text(displayURL)
              .font(.system(size: 10))
              .foregroundStyle(Brand.gray500)
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.gray100)
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
          .foregroundStyle(Brand.gray500)
          .lineLimit(1)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Brand.gray100)
    }
  }
}

// MARK: - Key hints

struct KeyHint: Identifiable {
  let keys: String
  let label: String
  var id: String { keys + label }
}

/// A quiet strip of "key  action" pairs along the bottom edge of the drawer.
struct KeyHintBar: View {
  let hints: [KeyHint]
  var trailing: String? = nil

  var body: some View {
    HStack(spacing: 16) {
      ForEach(hints) { hint in
        HStack(spacing: 6) {
          Text(hint.keys)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Brand.gray700)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(Brand.gray100)
            .overlay(Rectangle().stroke(Brand.gray300, lineWidth: 1))
          Text(hint.label)
            .font(.system(size: 11))
            .foregroundStyle(Brand.gray600)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hint.label): \(hint.keys)")
      }
      Spacer(minLength: 12)
      if let trailing {
        Text(trailing)
          .font(.system(size: 11))
          .foregroundStyle(Brand.gray500)
          .fixedSize()
      }
    }
    .padding(.horizontal, 20)
    .frame(height: 28)
    .background(Brand.white)
    .overlay(alignment: .top) { Rectangle().fill(Brand.gray200).frame(height: 1) }
    .clipped()
  }
}

// MARK: - Drawer support types

/// Card positions for anchoring the preview arrow. A reference type so
/// writes during scrolling do not invalidate the drawer.
final class CardPositions {
  var centerX: [Int: CGFloat] = [:]
}

/// Memo for the drawer's visible item list.
final class VisibleItemsCache {
  struct Key: Equatable {
    let historyVersion: Int
    let query: String
    let filter: FilterTag
    let pinboardId: UUID?
    let pinboards: [Pinboard]
  }
  var key: Key?
  var items: [ClipboardItem] = []
}

/// The hold-Space-to-edit ring. Observes the progress object itself so the
/// 60fps updates stay inside this small view.
struct HoldRingOverlay: View {
  @ObservedObject var hold: HoldProgress

  var body: some View {
    if hold.value > 0 {
      ZStack {
        // Plate: the ring sits on top of card text or a link image, so it
        // needs its own backing to stay readable
        Circle()
          .fill(Brand.white.opacity(0.92))
          .frame(width: 70, height: 70)

        // Background ring (subtle)
        Circle()
          .stroke(Brand.black.opacity(0.2), lineWidth: 3)
          .frame(width: 50, height: 50)

        // Progress ring (fills clockwise)
        Circle()
          .trim(from: 0, to: hold.value)
          .stroke(
            Brand.black.opacity(0.9),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
          .frame(width: 50, height: 50)
          .rotationEffect(.degrees(-90))  // Start from top

        // Edit icon in center
        Image(systemName: "pencil")
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(Brand.black)
          .opacity(0.7 + hold.value * 0.3)
      }
    }
  }
}

/// Thumbnail for an image clip. Shows the cached thumbnail immediately when
/// there is one; otherwise loads it off the main thread behind a placeholder.
struct ClipThumbnailView: View {
  let item: ClipboardItem
  var contentMode: ContentMode = .fit
  @State private var loaded: NSImage?

  var body: some View {
    Group {
      if let image = loaded ?? item.cachedThumbnail {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else {
        Image(systemName: "photo")
          .font(.system(size: 28))
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .onAppear { load() }
    .onChange(of: item.id) { _ in
      loaded = nil
      load()
    }
  }

  private func load() {
    guard loaded == nil, item.cachedThumbnail == nil else { return }
    let id = item.id
    item.loadThumbnail { image in
      // The view may have been reused for another clip in the meantime
      if id == item.id { loaded = image }
    }
  }
}

// MARK: - Item Context Menu

struct ItemContextMenu: View {
  let item: ClipboardItem
  /// App the paste will land in; empty when unknown
  let currentAppName: String
  let pinboards: [Pinboard]
  let onSelect: () -> Void
  var onCopy: (() -> Void)?
  var onPasteAsPlainText: (() -> Void)?
  var onEdit: (() -> Void)?
  var onDelete: (() -> Void)?
  var onPreview: (() -> Void)?
  var onPinTo: ((Pinboard) -> Void)?
  var onUnpinFrom: ((Pinboard) -> Void)?

  private var isTextual: Bool { item.type == .text || item.type == .url }

  var body: some View {
    Button {
      onSelect()
    } label: {
      Label(
        currentAppName.isEmpty ? "Paste" : "Paste to \(currentAppName)",
        systemImage: "arrow.down.doc")
    }
    .keyboardShortcut(.return, modifiers: [])

    if isTextual {
      Button {
        onPasteAsPlainText?()
      } label: {
        Label("Paste as Plain Text", systemImage: "doc.plaintext")
      }
      .keyboardShortcut(.return, modifiers: .shift)
    }

    Button {
      onCopy?()
    } label: {
      Label("Copy", systemImage: "doc.on.doc")
    }
    .keyboardShortcut("c", modifiers: .command)

    Divider()

    Button {
      onPreview?()
    } label: {
      Label("Preview", systemImage: "eye")
    }
    .keyboardShortcut(.space, modifiers: [])

    if isTextual {
      Button {
        onEdit?()
      } label: {
        Label("Edit (hold Space)", systemImage: "pencil")
      }
    }

    // Quick Actions submenu (context-aware)
    QuickActionsContextMenu(item: item)

    Divider()

    // Pin submenu: a checked board already holds this clip; choosing it unpins
    Menu {
      ForEach(pinboards) { pinboard in
        Toggle(
          isOn: Binding(
            get: { pinboard.itemIds.contains(item.id) },
            set: { isOn in
              if isOn {
                onPinTo?(pinboard)
              } else {
                onUnpinFrom?(pinboard)
              }
            }
          )
        ) {
          Label {
            Text(pinboard.name)
          } icon: {
            // Menus render SF Symbols as templates and drop their tint, so
            // the pinboard colour needs a real bitmap.
            Image(nsImage: coloredCircleImage(color: pinboard.color.nsColor))
          }
        }
      }
      if pinboards.isEmpty {
        Text("No pinboards yet. Use + in the drawer header.")
      }
    } label: {
      Label("Pin", systemImage: "pin")
    }

    Divider()

    Button(role: .destructive) {
      onDelete?()
    } label: {
      Label("Delete", systemImage: "trash")
    }
    .keyboardShortcut(.delete, modifiers: [])
  }
}

// MARK: - Media Thumbnail Cache

/// Shared cache for generated video thumbnails, keyed by file URL.
/// Without it, every scroll-back re-runs an AVAssetImageGenerator job.
enum MediaThumbnailCache {
  static let shared: NSCache<NSURL, NSImage> = {
    let c = NSCache<NSURL, NSImage>()
    c.countLimit = 40
    return c
  }()
}

// MARK: - File Image Thumbnail View

/// Downsampled, cached thumbnail for image files referenced by file-type cards.
/// Avoids decoding full-resolution images inside the SwiftUI view body.
struct FileImageThumbnailView: View {
  let url: URL
  @State private var thumbnail: NSImage?

  private static let cache: NSCache<NSURL, NSImage> = {
    let c = NSCache<NSURL, NSImage>()
    c.countLimit = 30
    c.totalCostLimit = 20 * 1024 * 1024  // 20 MB
    return c
  }()

  var body: some View {
    Group {
      if let thumbnail = thumbnail {
        Image(nsImage: thumbnail)
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        Rectangle()
          .fill(Color.gray.opacity(0.15))
          .overlay(
            Image(systemName: "photo")
              .font(.system(size: 24))
              .foregroundStyle(.tertiary)
          )
      }
    }
    .onAppear { loadThumbnail() }
  }

  private func loadThumbnail() {
    let key = url as NSURL
    if let cached = Self.cache.object(forKey: key) {
      thumbnail = cached
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let options: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: 440,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
      ]
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
      else { return }
      let image = NSImage(
        cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
      DispatchQueue.main.async {
        Self.cache.setObject(image, forKey: key, cost: cgThumb.width * cgThumb.height * 4)
        self.thumbnail = image
      }
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
        // Fixed white-on-dark: it sits on a video frame, not on app chrome
        Image(systemName: "play.circle.fill")
          .font(.system(size: 36))
          .symbolRenderingMode(.palette)
          .foregroundStyle(Color.white, Color.black.opacity(0.55))

        Text("VIDEO")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.8))
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(Brand.gray200)
      }
    }
    .onAppear {
      generateThumbnail()
    }
  }

  private func generateThumbnail() {
    if let cached = MediaThumbnailCache.shared.object(forKey: url as NSURL) {
      thumbnail = cached
      return
    }
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
          MediaThumbnailCache.shared.setObject(image, forKey: url as NSURL)
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
          Rectangle()
            .fill(Brand.gray500)
            // Fixed pseudo-random heights: random() here redrew a different
            // waveform every time the card re-rendered
            .frame(width: 6, height: 15 + CGFloat((i * 37 + 13) % 36))
        }
      }

      // Audio icon and label
      HStack(spacing: 8) {
        Image(systemName: "waveform.circle.fill")
          .font(.system(size: 24))
          .foregroundStyle(Brand.gray500)

        VStack(alignment: .leading, spacing: 2) {
          Text("AUDIO")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Brand.gray600)
          Text(url.pathExtension.uppercased())
            .font(.system(size: 9))
            .foregroundStyle(Brand.gray500)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Brand.gray100)
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
    // Rich text saved from a light-mode app carries black text; remap it so
    // it stays readable on a dark card
    textView.usesAdaptiveColorMappingForDarkAppearance = true
    textView.textStorage?.setAttributedString(attributedString)
    return textView
  }

  func updateNSView(_ nsView: NSTextView, context: Context) {
    if nsView.textStorage?.isEqual(to: attributedString) != true {
      nsView.textStorage?.setAttributedString(attributedString)
    }
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
      .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(Brand.gray600))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        isSelected
          ? Color.primary.opacity(0.18)
          : (isHovered ? Color.primary.opacity(0.1) : Color.primary.opacity(0.05))
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
    .accessibilityLabel("Show \(tag.rawValue)")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
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

  var body: some View {
    Image(systemName: icon)
      .font(.system(size: 8, weight: .semibold))
      .foregroundStyle(Brand.gray500)
      .frame(width: 16, height: 16)
      .background(Brand.gray100)
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
        .background(isHovered ? Brand.gray200 : Color.clear)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
    .help(helpText ?? "")
    .accessibilityLabel(helpText ?? icon)
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
              .foregroundStyle(Brand.gray600)
          }
        }
        .frame(minWidth: 28, minHeight: 28)
        .padding(.horizontal, 6)
        .background(
          isSelected
            ? Brand.gray200 : (isHovered ? Brand.gray100 : Color.clear)
        )
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
              .foregroundStyle(Brand.gray600)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Brand.gray100)
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
          isSelected
            ? Brand.gray200 : (isHovered ? Brand.gray100 : Color.clear)
        )
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
      return Brand.gray300
    } else if dragState.draggedItemId != nil {
      return Brand.gray200
    } else if isSelected {
      return Brand.gray200
    } else if isHovered {
      return Brand.gray100
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
              .foregroundStyle(Brand.gray600)
          }
        }
        .padding(10)
        .background(backgroundColor)
      } else {
        HStack(spacing: 7) {
          Circle()
            .fill(pinboard.color.color)
            .frame(width: 8, height: 8)
          Text(pinboard.name)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary.opacity(0.9))
            .lineLimit(1)
            .truncationMode(.tail)
            // Natural width, capped: long names truncate instead of wrapping
            .frame(maxWidth: 160)
            .fixedSize(horizontal: true, vertical: false)
          if let count = itemCount {
            Text("\(count)")
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(Brand.gray600)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Brand.gray100)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(backgroundColor)
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
    .help(pinboard.name)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(pinboard.name) pinboard, \(pinboard.itemIds.count) items")
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .contextMenu {
      Button {
        onEdit()
      } label: {
        Label("Rename", systemImage: "pencil")
      }

      Divider()
      PinboardColorPicker(currentColor: pinboard.color, onColorChange: onColorChange)
      Divider()
      if pinboard.itemIds.isEmpty {
        Button(role: .destructive) {
          onDelete()
        } label: {
          Label("Delete Pinboard", systemImage: "trash")
        }
      } else {
        // Deleting can't be undone, so a board with clips takes a second,
        // deliberate click. The clips themselves stay in history.
        Menu {
          Button(role: .destructive) {
            onDelete()
          } label: {
            Label(
              "Delete \u{201C}\(pinboard.name)\u{201D} and unpin \(pinboard.itemIds.count) \(pinboard.itemIds.count == 1 ? "clip" : "clips")",
              systemImage: "trash")
          }
        } label: {
          Label("Delete Pinboard", systemImage: "trash")
        }
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
  @Binding var color: PinboardColor
  @FocusState.Binding var isFocused: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
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

      HStack(spacing: 4) {
        ForEach(PinboardColor.allCases, id: \.self) { option in
          Circle()
            .fill(option.color)
            .frame(width: 10, height: 10)
            .overlay(
              Circle()
                .stroke(Color.primary.opacity(color == option ? 0.8 : 0), lineWidth: 1.5)
            )
            .onTapGesture {
              color = option
            }
        }
      }
      .padding(.leading, 12)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(Brand.gray100)
    .overlay(Rectangle().stroke(Brand.gray200, lineWidth: 1))
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
