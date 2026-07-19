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
    /// Identity + timestamp of the last history front item we processed.
    /// Count-based detection missed re-copies (dedup moves an item to the
    /// front without changing the count), silently dropping stack entries.
    private var lastSeenFront: (id: UUID, timestamp: Date)?

    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }

    /// Start a new paste stack session - clears previous items and begins tracking new copies
    func startSession() {
        stackItems.removeAll()
        isActive = true
        lastSeenFront = clipboardManager.history.first.map { ($0.id, $0.timestamp) }

        // Listen for new clipboard items
        cancellable = clipboardManager.$history
            .dropFirst() // Skip the initial value
            .sink { [weak self] history in
                guard let self = self, self.isActive else { return }
                guard let front = history.first else { return }

                // Only react when the front item is new or freshly re-copied
                let isNewFront = self.lastSeenFront?.id != front.id
                    || self.lastSeenFront?.timestamp != front.timestamp
                self.lastSeenFront = (front.id, front.timestamp)
                guard isNewFront else { return }

                // Check if we already have this item (by unique identifier)
                if !self.stackItems.contains(where: { $0.uniqueIdentifier == front.uniqueIdentifier }) {
                    DispatchQueue.main.async {
                        self.stackItems.append(front)
                        // Keep the stack head loaded on the clipboard so Cmd+V
                        // pastes in queue order. Without this, the clipboard
                        // holds the most recent copy and the first pastes come
                        // out of order (last, then first, ...).
                        if self.stackItems.count >= 2, let head = self.stackItems.first {
                            self.clipboardManager.copyToClipboard(head)
                        }
                    }
                }
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
