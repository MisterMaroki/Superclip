//
//  BrandColors.swift
//  Superclip
//

import SwiftUI
import AppKit

enum Brand {
    static let white = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.11, alpha: 1)
            : NSColor(white: 0.98, alpha: 1)
    })

    static let gray100 = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.14, alpha: 1)
            : NSColor(white: 0.96, alpha: 1)
    })

    static let gray200 = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.20, alpha: 1)
            : NSColor(white: 0.898, alpha: 1)
    })

    static let gray300 = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.27, alpha: 1)
            : NSColor(white: 0.831, alpha: 1)
    })

    static let gray400 = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.45, alpha: 1)
            : NSColor(white: 0.639, alpha: 1)
    })

    static let gray500 = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.60, alpha: 1)
            : NSColor(white: 0.42, alpha: 1)
    })

    static let gray600 = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.65, alpha: 1)
            : NSColor(white: 0.322, alpha: 1)
    })

    static let gray700 = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.74, alpha: 1)
            : NSColor(white: 0.251, alpha: 1)
    })

    static let gray800 = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.85, alpha: 1)
            : NSColor(white: 0.149, alpha: 1)
    })

    static let black = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.96, alpha: 1)
            : NSColor(white: 0.039, alpha: 1)
    })
}
