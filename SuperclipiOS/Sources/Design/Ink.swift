//
//  Ink.swift
//  Superclip for iPhone
//
//  The design system shared with the Mac app: paper and ink neutrals, square
//  geometry, mono metadata, and one colour rule per content type. Colour is
//  spent on the content, never on chrome.
//

import SwiftUI
import UIKit

extension Color {
    /// A colour with separate light and dark values (0xRRGGBB).
    init(light: UInt32, dark: UInt32) {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

enum Ink {
    // Surfaces, back to front
    static let paper = Color(light: 0xF6F6F4, dark: 0x0B0B0C)
    static let surface = Color(light: 0xFFFFFF, dark: 0x161617)
    static let sunken = Color(light: 0xEDEDEA, dark: 0x202022)
    static let line = Color(light: 0xDEDEDA, dark: 0x2E2E31)

    // Text
    static let ink = Color(light: 0x0A0A0A, dark: 0xF5F5F3)
    static let ink2 = Color(light: 0x55554F, dark: 0xA9A9A4)
    static let ink3 = Color(light: 0x8C8C86, dark: 0x70706C)
    /// Text on an ink-filled control
    static let onInk = Color(light: 0xFAFAF8, dark: 0x0B0B0C)

    static let danger = Color(light: 0xC62828, dark: 0xFF6B60)

    // Spacing scale (pt)
    static let gutter: CGFloat = 16
    static let gap: CGFloat = 10
}

// MARK: - Type

extension View {
    /// Section and field labels: small mono capitals, widely tracked.
    func inkLabel() -> some View {
        font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Ink.ink3)
    }

    /// Metadata: counts, times, dimensions.
    func inkMeta() -> some View {
        font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Ink.ink3)
    }
}

// MARK: - Controls

/// Solid ink button: the one primary action on a screen.
struct InkButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(prominent ? Ink.onInk : Ink.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 46)
            .frame(maxWidth: .infinity)
            .background(prominent ? Ink.ink : Ink.sunken)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// Square filter chip. Selected = ink fill.
struct InkChip: View {
    let title: String
    var dot: Color? = nil
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Rectangle().fill(dot).frame(width: 7, height: 7)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .opacity(0.6)
                }
            }
            .foregroundStyle(isSelected ? Ink.onInk : Ink.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isSelected ? Ink.ink : Ink.surface)
            .overlay(Rectangle().strokeBorder(isSelected ? Ink.ink : Ink.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Square on/off indicator, the same shape as the Mac app's switch.
struct InkSwitch: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Rectangle().fill(isOn ? Ink.ink : Ink.line).frame(width: 44, height: 26)
            Rectangle().fill(Ink.surface).frame(width: 18, height: 18).padding(4)
        }
        .animation(.snappy(duration: 0.16), value: isOn)
    }
}

/// Brief confirmation that slides up from the bottom edge.
struct InkToast: View {
    let text: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Ink.onInk)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Ink.onInk)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .overlay(Rectangle().strokeBorder(Ink.onInk.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, actionTitle == nil ? 16 : 8)
        .frame(height: 44)
        .background(Ink.ink)
        .accessibilityElement(children: .combine)
    }
}

/// Empty state: a mark, a headline that names the space, one line of help.
struct InkEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Ink.ink3)
                .frame(width: 64, height: 64)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
                .padding(.bottom, 6)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Ink.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Ink.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
