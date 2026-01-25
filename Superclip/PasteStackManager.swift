//
//  PasteStackManager.swift
//  Superclip
//

import Foundation
import Combine

class PasteStackManager: ObservableObject {
    @Published var stackItems: [ClipboardItem] = []
    
    private var clipboardManager: ClipboardManager
    private var cancellable: AnyCancellable?
    private var isActive: Bool = false
    private var lastKnownChangeCount: Int = 0
    
    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }
    
    /// Start a new paste stack session - clears previous items and begins tracking new copies
    func startSession() {
        stackItems.removeAll()
        isActive = true
        lastKnownChangeCount = clipboardManager.history.count
        
        // Listen for new clipboard items
        cancellable = clipboardManager.$history
            .dropFirst() // Skip the initial value
            .sink { [weak self] history in
                guard let self = self, self.isActive else { return }
                
                // If there's a new item at the front, add it to our stack
                if history.count > self.lastKnownChangeCount, let newItem = history.first {
                    // Check if we already have this item (by unique identifier)
                    if !self.stackItems.contains(where: { $0.uniqueIdentifier == newItem.uniqueIdentifier }) {
                        DispatchQueue.main.async {
                            self.stackItems.append(newItem)
                        }
                    }
                }
                self.lastKnownChangeCount = history.count
            }
    }
    
    /// End the paste stack session
    func endSession() {
        isActive = false
        cancellable?.cancel()
        cancellable = nil
    }
    
    /// Remove an item from the stack
    func removeItem(_ item: ClipboardItem) {
        stackItems.removeAll { $0.id == item.id }
    }
    
    /// Clear all items from the stack
    func clearStack() {
        stackItems.removeAll()
    }
    
    /// Get the next item to paste (first in queue) and remove it
    func popNextItem() -> ClipboardItem? {
        guard !stackItems.isEmpty else { return nil }
        return stackItems.removeFirst()
    }
    
    /// Copy an item to clipboard (for pasting)
    func copyToClipboard(_ item: ClipboardItem) {
        clipboardManager.copyToClipboard(item)
    }
    
    /// Called after user pastes - removes the pasted item and copies next item to clipboard
    func advanceAfterPaste() {
        guard !stackItems.isEmpty else { return }
        
        // Remove the first item (the one that was just pasted)
        stackItems.removeFirst()
        
        // Copy the next item to clipboard so it's ready for the next paste
        if let nextItem = stackItems.first {
            clipboardManager.copyToClipboard(nextItem)
        }
    }
}
