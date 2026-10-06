//
//  PinboardManager.swift
//  Superclip
//

import Foundation
import Combine

class PinboardManager: ObservableObject {
    @Published var pinboards: [Pinboard] = []
    
    private let storageKey = "SuperclipPinboards"
    private let storage = UserDefaults.standard
    
    init() {
        loadPinboards()
    }
    
    // MARK: - Persistence
    
    private func loadPinboards() {
        guard let data = storage.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Pinboard].self, from: data) else {
            pinboards = []
            return
        }
        pinboards = decoded
    }
    
    private func savePinboards() {
        guard let encoded = try? JSONEncoder().encode(pinboards) else { return }
        storage.set(encoded, forKey: storageKey)
    }
    
    // MARK: - Pinboard Management
    
    func createPinboard(name: String = "Untitled", color: PinboardColor = .red) -> Pinboard {
        let pinboard = Pinboard(name: name, color: color)
        pinboards.append(pinboard)
        savePinboards()
        return pinboard
    }
    
    func updatePinboard(_ pinboard: Pinboard) {
        guard let index = pinboards.firstIndex(where: { $0.id == pinboard.id }) else { return }
        pinboards[index] = pinboard
        savePinboards()
    }
    
    func deletePinboard(_ pinboard: Pinboard) {
        pinboards.removeAll { $0.id == pinboard.id }
        savePinboards()
        onPinboardsDeleted?([pinboard.id])
    }

    /// Called when the user deletes pinboards (not when a deletion arrives from sync).
    var onPinboardsDeleted: (([UUID]) -> Void)?

    // MARK: - Sync

    /// Insert or replace a pinboard that arrived from iCloud.
    func applyRemote(_ pinboard: Pinboard, position: Int) {
        var updated = pinboards
        updated.removeAll { $0.id == pinboard.id }
        updated.insert(pinboard, at: min(max(position, 0), updated.count))
        pinboards = updated
        savePinboards()
    }

    func applyRemoteDelete(_ id: UUID) {
        guard pinboards.contains(where: { $0.id == id }) else { return }
        pinboards.removeAll { $0.id == id }
        savePinboards()
    }

    /// Point pins at a different clip (two copies of the same clip were merged).
    func replaceItem(_ old: UUID, with new: UUID) {
        var changed = false
        for i in pinboards.indices where pinboards[i].itemIds.contains(old) {
            pinboards[i].itemIds = SyncMerge.remap(pinboards[i].itemIds, replacing: old, with: new)
            changed = true
        }
        if changed { savePinboards() }
    }
    
    // MARK: - Item Management
    
    func addItem(_ itemId: UUID, to pinboard: Pinboard) {
        guard let index = pinboards.firstIndex(where: { $0.id == pinboard.id }) else { return }
        var updated = pinboards[index]
        if !updated.itemIds.contains(itemId) {
            updated.itemIds.append(itemId)
            pinboards[index] = updated
            savePinboards()
        }
    }
    
    func removeItem(_ itemId: UUID, from pinboard: Pinboard) {
        guard let index = pinboards.firstIndex(where: { $0.id == pinboard.id }) else { return }
        var updated = pinboards[index]
        updated.itemIds.removeAll { $0 == itemId }
        pinboards[index] = updated
        savePinboards()
    }
    
    func getItems(for pinboard: Pinboard, from allItems: [ClipboardItem]) -> [ClipboardItem] {
        // Set lookup: Array.contains inside the filter is O(history x pins)
        let ids = Set(pinboard.itemIds)
        return allItems.filter { ids.contains($0.id) }
    }

    /// Merge imported pinboards. A board that already exists (same ID) gains
    /// any pins it is missing; new boards are added. Nothing is removed.
    /// - Returns: how many boards were added.
    @discardableResult
    func mergeImported(_ imported: [Pinboard], remappingItemIds idMap: [UUID: UUID] = [:]) -> Int {
        var added = 0
        for var board in imported {
            board.itemIds = board.itemIds.map { idMap[$0] ?? $0 }
            if let index = pinboards.firstIndex(where: { $0.id == board.id }) {
                for id in board.itemIds where !pinboards[index].itemIds.contains(id) {
                    pinboards[index].itemIds.append(id)
                }
            } else {
                pinboards.append(board)
                added += 1
            }
        }
        savePinboards()
        return added
    }

    /// Drop references to items that no longer exist.
    func removeItems(_ itemIds: [UUID]) {
        guard !itemIds.isEmpty else { return }
        let gone = Set(itemIds)
        var changed = false
        for i in pinboards.indices where pinboards[i].itemIds.contains(where: gone.contains) {
            pinboards[i].itemIds.removeAll(where: gone.contains)
            changed = true
        }
        if changed { savePinboards() }
    }

    /// Drop references to anything not in `validIds` (launch-time cleanup of
    /// pins left behind by earlier versions).
    func removeItems(notIn validIds: Set<UUID>) {
        var changed = false
        for i in pinboards.indices where pinboards[i].itemIds.contains(where: { !validIds.contains($0) }) {
            pinboards[i].itemIds.removeAll { !validIds.contains($0) }
            changed = true
        }
        if changed { savePinboards() }
    }

    // MARK: - Aggregate Helpers

    var totalPinnedItemCount: Int {
        pinboards.reduce(0) { $0 + $1.itemIds.count }
    }

    func clearAllPinboards() {
        for i in pinboards.indices {
            pinboards[i].itemIds.removeAll()
        }
        savePinboards()
    }
}
