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
        return allItems.filter { pinboard.itemIds.contains($0.id) }
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
