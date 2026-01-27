//
//  Pinboard.swift
//  Superclip
//

import Foundation
import SwiftUI

struct Pinboard: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var color: PinboardColor
    var itemIds: [UUID] // References to ClipboardItem IDs
    
    init(id: UUID = UUID(), name: String, color: PinboardColor = .red, itemIds: [UUID] = []) {
        self.id = id
        self.name = name
        self.color = color
        self.itemIds = itemIds
    }
    
    static func == (lhs: Pinboard, rhs: Pinboard) -> Bool {
        lhs.id == rhs.id
    }
}

enum PinboardColor: String, Codable, CaseIterable {
    case red
    case yellow
    case green
    case blue
    case purple
    case orange
    case pink
    case cyan
    
    var color: Color {
        switch self {
        case .red:
            return Color.red
        case .yellow:
            return Color.yellow
        case .green:
            return Color.green
        case .blue:
            return Color.blue
        case .purple:
            return Color.purple
        case .orange:
            return Color.orange
        case .pink:
            return Color.pink
        case .cyan:
            return Color.cyan
        }
    }
    
    var nsColor: NSColor {
        switch self {
        case .red:
            return NSColor.systemRed
        case .yellow:
            return NSColor.systemYellow
        case .green:
            return NSColor.systemGreen
        case .blue:
            return NSColor.systemBlue
        case .purple:
            return NSColor.systemPurple
        case .orange:
            return NSColor.systemOrange
        case .pink:
            return NSColor.systemPink
        case .cyan:
            return NSColor.systemCyan
        }
    }
}
