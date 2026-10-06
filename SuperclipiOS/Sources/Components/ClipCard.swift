//
//  ClipCard.swift
//  Superclip for iPhone
//
//  One clip. Anatomy matches the Mac card: a 2pt rule in the type's colour,
//  a header line (what, when, where from), then the content itself.
//

import SwiftUI

struct ClipCard: View {
    let clip: Clip
    let pinboards: [Pinboard]
    let image: UIImage?
    var onMore: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(clip.kind.accent).frame(height: 2)

            header
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .frame(height: 36)

            content
        }
        .background(Ink.surface)
        .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Copies this clip")
        .accessibilityAddTraits(.isButton)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(clip.kind.label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Ink.ink)
            Text(clip.lastUsedAt.shortRelative)
                .inkMeta()

            // Pinboard membership sits with "what and when", away from the
            // source app, so the squares can't be read as the app's colour
            if !pinboards.isEmpty {
                HStack(spacing: 3) {
                    ForEach(pinboards) { board in
                        Rectangle().fill(board.tint.color).frame(width: 7, height: 7)
                    }
                }
                .padding(.leading, 2)
                .accessibilityHidden(true)
            }

            Spacer(minLength: 6)

            if let app = clip.sourceApp {
                Text(app)
                    .inkMeta()
                    .lineLimit(1)
            }
            Image(systemName: clip.isFromThisDevice ? "iphone" : "laptopcomputer")
                .font(.system(size: 11))
                .foregroundStyle(Ink.ink3)

            if let onMore {
                Button(action: onMore) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Ink.ink2)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Details")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch clip.kind {
        case .text:
            Text(clip.displayText)
                .font(.system(size: 15))
                .foregroundStyle(Ink.ink)
                .lineLimit(5)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

        case .code:
            Text(clip.displayText)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(Ink.ink)
                .lineLimit(6)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Ink.sunken)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

        case .link:
            HStack(alignment: .top, spacing: 12) {
                Text(String((clip.host ?? "?").prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Ink.onInk)
                    .frame(width: 40, height: 40)
                    .background(Ink.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text(clip.title ?? clip.content)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.ink)
                        .lineLimit(2)
                    Text(clip.host ?? clip.content)
                        .inkMeta()
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

        case .image:
            ZStack(alignment: .bottomTrailing) {
                if let image {
                    Color.clear
                        .frame(height: 168)
                        .overlay(Image(uiImage: image).resizable().scaledToFill())
                        .clipped()
                } else {
                    Ink.sunken.frame(height: 168)
                        .overlay(Image(systemName: "photo").font(.system(size: 26)).foregroundStyle(Ink.ink3))
                }
                Text(clip.measure)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Color.black.opacity(0.62))
                    .padding(8)
            }

        case .color:
            ColorSwatch(text: clip.displayText)
                .frame(height: 84)
        }
    }

    private var accessibilityLabel: String {
        var parts = [clip.kind.label]
        if let app = clip.sourceApp { parts.append("from \(app)") }
        parts.append(clip.kind == .image ? clip.measure : String(clip.displayText.prefix(120)))
        return parts.joined(separator: ", ")
    }
}

/// A colour clip shown as the colour itself. The label picks black or white
/// from the colour's brightness, not from the app theme.
struct ColorSwatch: View {
    let text: String

    var body: some View {
        let rgb = ClipClassifier.rgb(from: text) ?? (0.5, 0.5, 0.5)
        let prefersDark = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b > 0.6
        ZStack(alignment: .bottomLeading) {
            Color(red: rgb.r, green: rgb.g, blue: rgb.b)
            Text(text.uppercased())
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(prefersDark ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                .padding(12)
        }
    }
}

extension Date {
    /// "now", "4m", "2h", "3d": short enough for a card header.
    var shortRelative: String {
        let seconds = Int(Date().timeIntervalSince(self))
        if seconds < 45 { return "now" }
        if seconds < 3600 { return "\(max(1, seconds / 60))m" }
        if seconds < 86_400 { return "\(seconds / 3600)h" }
        if seconds < 604_800 { return "\(seconds / 86_400)d" }
        return formatted(.dateTime.day().month(.abbreviated))
    }
}
