//
//  NavigationState.swift
//  Superclip
//

import Foundation
import Combine

/// Progress of the hold-Space-to-edit gesture. Its own object because it
/// changes 60 times a second while Space is held: published from
/// NavigationState it re-rendered the entire drawer on every tick. Only the
/// small progress ring observes this.
final class HoldProgress: ObservableObject {
    @Published var value: Double = 0
}

class NavigationState: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var shouldSelectAndDismiss: Bool = false
    @Published var shouldFocusSearch: Bool = false
    @Published var shouldShowPreview: Bool = false
    @Published var shouldDeleteCurrent: Bool = false
    /// Signal to paste the selected item as plain text (Shift+Return)
    @Published var shouldPastePlainAndDismiss: Bool = false
    /// Signal to copy the selected item without closing the drawer (Cmd+C)
    @Published var shouldCopyCurrent: Bool = false
    @Published var isCommandHeld: Bool = false
    
    /// Hold-to-edit: progress 0...1 while spacebar held. Springs back to 0 on early release.
    let hold = HoldProgress()
    var holdProgress: Double {
        get { hold.value }
        set { if hold.value != newValue { hold.value = newValue } }
    }
    @Published var isHoldingSpace: Bool = false

    /// Pending search text from type-to-search (characters typed before search field focused)
    @Published var pendingSearchText: String = ""

    /// Signal to close search field (e.g., when arrow navigating with empty search)
    @Published var shouldCloseSearch: Bool = false

    /// Signal to clear search text and close search field (e.g., ESC key)
    @Published var shouldClearAndCloseSearch: Bool = false

    /// Whether the preview panel is currently visible (set by AppDelegate)
    @Published var isPreviewVisible: Bool = false

    /// Signal to navigate to the previous pinboard (Cmd+Left)
    @Published var shouldMovePinboardLeft: Bool = false

    /// Signal to navigate to the next pinboard (Cmd+Right)
    @Published var shouldMovePinboardRight: Bool = false

    var itemCount: Int = 0

    /// ID of the currently selected item in ContentView's *visible* (filtered/
    /// pinboard) list. AppDelegate flows must resolve items through this, not
    /// by indexing clipboardManager.history with selectedIndex — the two lists
    /// diverge whenever search or a pinboard is active. Not @Published: it's a
    /// data channel, not UI state.
    var selectedItemId: UUID?

    /// Select item by quick-access digit (1-9 for first 9 items, 0 for 10th item)
    func selectByDigit(_ digit: Int) {
        let targetIndex = digit == 0 ? 9 : digit - 1
        if targetIndex < itemCount {
            selectedIndex = targetIndex
            shouldSelectAndDismiss = true
        }
    }
    
    func moveRight() {
        if itemCount > 0 {
            selectedIndex = min(selectedIndex + 1, itemCount - 1)
        }
    }
    
    func moveLeft() {
        selectedIndex = max(selectedIndex - 1, 0)
    }
    
    func selectCurrent() {
        shouldSelectAndDismiss = true
    }
    
    func reset() {
        selectedIndex = 0
        shouldSelectAndDismiss = false
        shouldPastePlainAndDismiss = false
        shouldCopyCurrent = false
        shouldFocusSearch = false
        shouldShowPreview = false
        shouldDeleteCurrent = false
        pendingSearchText = ""
        shouldCloseSearch = false
        shouldClearAndCloseSearch = false
        shouldMovePinboardLeft = false
        shouldMovePinboardRight = false
    }
    
    func focusSearch() {
        shouldFocusSearch = true
    }
    
    func showPreview() {
        shouldShowPreview = true
    }
    
    func deleteCurrentItem() {
        shouldDeleteCurrent = true
    }

    func movePinboardLeft() {
        shouldMovePinboardLeft = true
    }

    func movePinboardRight() {
        shouldMovePinboardRight = true
    }
}
