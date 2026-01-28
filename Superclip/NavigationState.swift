//
//  NavigationState.swift
//  Superclip
//

import Foundation
import Combine

class NavigationState: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var shouldSelectAndDismiss: Bool = false
    @Published var shouldFocusSearch: Bool = false
    @Published var shouldShowPreview: Bool = false
    @Published var shouldDeleteCurrent: Bool = false
    @Published var isCommandHeld: Bool = false
    
    /// Hold-to-edit: progress 0...1 while spacebar held. Springs back to 0 on early release.
    @Published var holdProgress: Double = 0
    @Published var isHoldingSpace: Bool = false

    /// Pending search text from type-to-search (characters typed before search field focused)
    @Published var pendingSearchText: String = ""

    /// Signal to close search field (e.g., when arrow navigating with empty search)
    @Published var shouldCloseSearch: Bool = false

    /// Signal to clear search text and close search field (e.g., ESC key)
    @Published var shouldClearAndCloseSearch: Bool = false

    var itemCount: Int = 0

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
        shouldFocusSearch = false
        shouldShowPreview = false
        shouldDeleteCurrent = false
        pendingSearchText = ""
        shouldCloseSearch = false
        shouldClearAndCloseSearch = false
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
}
