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
    
    var itemCount: Int = 0
    
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
    }
    
    func focusSearch() {
        shouldFocusSearch = true
    }
    
    func showPreview() {
        shouldShowPreview = true
    }
}
