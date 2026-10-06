//
//  PasteStackManager.swift
//  Superclip
//

import Foundation
import Combine

class PasteStackManager: ObservableObject {
    /// Items in the order they were copied (oldest first).
    @Published var stackItems: [ClipboardItem] = []

    /// Paste order. Off: the first thing copied is pasted first. On: the most
    /// recent copy is pasted first. The list is shown in the same order, so
    /// the row numbered 1 is always what the next Cmd+V pastes.
    @Published var newestFirst: Bool = false {
        didSet {
            if oldValue != newestFirst { loadHead() }
        }
    }

    private var clipboardManager: ClipboardManager
    private var cancellable: AnyCancellable?
    private var isActive: Bool = false

    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }

    /// The item the next Cmd+V will paste.
    var head: ClipboardItem? {
        newestFirst ? stackItems.last : stackItems.first
    }

    /// Start a new paste stack session - clears previous items and begins tracking new copies
    func startSession() {
        stackItems.removeAll()
        isActive = true
        // Copy order matters here, so don't let two quick copies fall inside
        // one slow poll interval.
        clipboardManager.setFastPolling(true)

        // Listen for real copies only. Subscribing to `history` instead made
        // the stack react to its own pasteboard writes: clicking a row moved
        // that item to the front of history, which looked like a new copy, so
        // the item was queued again and a different one was pasted.
        cancellable = clipboardManager.captured
            .sink { [weak self] item in
                guard let self = self, self.isActive else { return }
                guard !self.stackItems.contains(where: { $0.uniqueIdentifier == item.uniqueIdentifier })
                else { return }

                self.stackItems.append(item)
                // The pasteboard now holds the newest copy. Put the queue head
                // back so Cmd+V pastes in queue order.
                if self.head?.id != item.id {
                    self.loadHead()
                }
            }
    }

    /// End the paste stack session
    func endSession() {
        isActive = false
        cancellable?.cancel()
        cancellable = nil
        clipboardManager.setFastPolling(false)
    }

    /// Put the queue head on the pasteboard without touching history order.
    private func loadHead() {
        guard isActive, let head = head else { return }
        clipboardManager.copyToClipboard(head, moveToFront: false)
    }

    /// Remove an item from the stack
    func removeItem(_ item: ClipboardItem) {
        let wasHead = head?.id == item.id
        stackItems.removeAll { $0.id == item.id }
        // The removed head is still on the pasteboard; replace it, or the next
        // Cmd+V pastes the very item that was just removed.
        if wasHead { loadHead() }
    }

    /// Clear all items from the stack
    func clearStack() {
        stackItems.removeAll()
    }

    /// Paste one specific item now (a click on its row): put it on the
    /// pasteboard and take it off the stack. The caller triggers the paste;
    /// once that has been consumed the queue head goes back on the pasteboard.
    func prepareToPaste(_ item: ClipboardItem) {
        clipboardManager.copyToClipboard(item, moveToFront: false)
        stackItems.removeAll { $0.id == item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.loadHead()
        }
    }

    /// Called after the user pastes with Cmd+V: drop the pasted item and load the next one.
    func advanceAfterPaste() {
        guard let pasted = head else { return }
        stackItems.removeAll { $0.id == pasted.id }
        loadHead()
    }
}
