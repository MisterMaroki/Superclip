//
//  ClipDetailSheet.swift
//  Superclip for iPhone
//
//  Everything about one clip: the whole content, where it came from, the
//  pinboards it is on, and what you can do with it.
//

import SwiftUI

struct ClipDetailSheet: View {
    @EnvironmentObject private var store: ClipStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let clipID: UUID

    private var clip: Clip? { store.clips.first { $0.id == clipID } }

    var body: some View {
        if let clip {
            VStack(spacing: 0) {
                Rectangle().fill(clip.kind.accent).frame(height: 3)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Text(clip.kind.label)
                                .font(.system(size: 22, weight: .heavy))
                                .tracking(-0.3)
                                .foregroundStyle(Ink.ink)
                            Spacer()
                            HeaderButton(symbol: "xmark", label: "Close") { dismiss() }
                        }

                        content(for: clip)

                        if clip.kind == .color { colorFormats(for: clip) }

                        section("Details") {
                            DetailRow(label: "Copied", value: clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                            if let app = clip.sourceApp { DetailRow(label: "From", value: app) }
                            DetailRow(label: "Device", value: clip.device)
                            DetailRow(label: "Size", value: clip.measure, isLast: true)
                        }

                        if !store.pinboards.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Pinboards").inkLabel()
                                FlowChips(clip: clip)
                            }
                        }
                    }
                    .padding(Ink.gutter)
                    .padding(.top, 6)
                }

                actions(for: clip)
            }
            .background(Ink.paper)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(0)
        }
    }

    @ViewBuilder
    private func content(for clip: Clip) -> some View {
        switch clip.kind {
        case .image:
            if let image = store.image(for: clip) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
            }
        case .color:
            ColorSwatch(text: clip.displayText)
                .frame(height: 120)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        case .link:
            VStack(alignment: .leading, spacing: 6) {
                if let title = clip.title {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Ink.ink)
                }
                Text(clip.content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Ink.ink2)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Ink.surface)
            .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        default:
            Text(clip.content)
                .font(clip.kind == .code ? .system(size: 13, design: .monospaced) : .system(size: 16))
                .foregroundStyle(Ink.ink)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Ink.surface)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        }
    }

    /// The same colour in each notation; tap one to copy it.
    private func colorFormats(for clip: Clip) -> some View {
        let rgb = ClipClassifier.rgb(from: clip.content) ?? (0, 0, 0)
        let r = Int((rgb.r * 255).rounded()), g = Int((rgb.g * 255).rounded()), b = Int((rgb.b * 255).rounded())
        let formats = [
            ("Hex", String(format: "#%02X%02X%02X", r, g, b)),
            ("RGB", "rgb(\(r), \(g), \(b))"),
            ("HSL", Self.hsl(r: rgb.r, g: rgb.g, b: rgb.b)),
        ]
        return section("Copy as") {
            ForEach(Array(formats.enumerated()), id: \.offset) { index, format in
                Button {
                    UIPasteboard.general.string = format.1
                    store.toast = ClipStore.Toast(text: "Copied \(format.0)")
                } label: {
                    DetailRow(label: format.0, value: format.1, isLast: index == formats.count - 1, trailingSymbol: "doc.on.doc")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static func hsl(r: Double, g: Double, b: Double) -> String {
        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        let l = (maxC + minC) / 2
        var h = 0.0, s = 0.0
        if delta > 0 {
            s = delta / (1 - abs(2 * l - 1))
            if maxC == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == g { h = (b - r) / delta + 2 }
            else { h = (r - g) / delta + 4 }
            h *= 60
            if h < 0 { h += 360 }
        }
        return "hsl(\(Int(h.rounded())), \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
    }

    private func actions(for clip: Clip) -> some View {
        HStack(spacing: 10) {
            Button {
                store.delete(clip)
                dismiss()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Ink.danger)
                    .frame(width: 46, height: 46)
                    .background(Ink.sunken)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")

            if clip.kind == .link, let url = URL(string: clip.content) {
                Button("Open") { openURL(url) }
                    .buttonStyle(InkButtonStyle(prominent: false))
            } else if clip.kind != .image {
                ShareLink(item: clip.content) { Text("Share") }
                    .buttonStyle(InkButtonStyle(prominent: false))
            }

            Button("Copy") {
                store.copy(clip)
                dismiss()
            }
            .buttonStyle(InkButtonStyle())
        }
        .padding(.horizontal, Ink.gutter)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Ink.paper)
        .overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).inkLabel()
            VStack(spacing: 0) { content() }
                .background(Ink.surface)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var isLast = false
    var trailingSymbol: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Ink.ink2)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Ink.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.ink3)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(Ink.line).frame(height: 1).padding(.leading, 14) }
        }
    }
}

/// Pinboard toggles for a clip, wrapping onto as many lines as needed.
struct FlowChips: View {
    @EnvironmentObject private var store: ClipStore
    let clip: Clip

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { chips } }
        }
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(store.pinboards) { board in
            InkChip(title: board.name, dot: board.tint.color, isSelected: store.isPinned(clip, in: board)) {
                store.togglePin(clip, in: board)
            }
        }
    }
}

/// Quick pin sheet from a swipe: just the boards.
struct PinSheet: View {
    @EnvironmentObject private var store: ClipStore
    @Environment(\.dismiss) private var dismiss
    let clipID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pin to")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Ink.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
            }
            if let clip = store.clips.first(where: { $0.id == clipID }) {
                if store.pinboards.isEmpty {
                    Text("No pinboards yet. Create one in the Pinboards tab.")
                        .font(.system(size: 14))
                        .foregroundStyle(Ink.ink2)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.pinboards) { board in
                            Button {
                                store.togglePin(clip, in: board)
                            } label: {
                                HStack(spacing: 12) {
                                    Rectangle().fill(board.tint.color).frame(width: 10, height: 10)
                                    Text(board.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Ink.ink)
                                    Spacer()
                                    Image(systemName: store.isPinned(clip, in: board) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 20))
                                        .foregroundStyle(store.isPinned(clip, in: board) ? Ink.ink : Ink.ink3)
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 52)
                                .contentShape(Rectangle())
                                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Ink.surface)
                    .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Ink.gutter)
        .padding(.top, 10)
        .background(Ink.paper)
        .presentationDetents([.height(CGFloat(150 + max(1, store.pinboards.count) * 52))])
        .presentationCornerRadius(0)
    }
}
