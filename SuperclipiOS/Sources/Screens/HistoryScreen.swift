//
//  HistoryScreen.swift
//  Superclip for iPhone
//
//  The clipboard: everything copied, newest first. Tap a clip to copy it.
//  Search sits at the bottom, where the thumb already is.
//

import SwiftUI
import UIKit

struct HistoryScreen: View {
    @EnvironmentObject private var store: ClipStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var query = LaunchOptions.screen == "search" ? "swift" : ""
    @State private var kind: ClipKind?
    @State private var detail: Clip?
    @State private var pinning: Clip?
    @State private var showingSettings = LaunchOptions.screen == "settings"
    @State private var clipboardHasContent = false
    @FocusState private var searchFocused: Bool

    private var visible: [Clip] {
        store.clips(in: nil, kind: kind, matching: query)
    }

    var body: some View {
        List {
            Group {
                ScreenHeader(title: "Clipboard", status: statusLine) {
                    HeaderButton(symbol: "gearshape", label: "Settings") { showingSettings = true }
                }

                if clipboardHasContent {
                    CaptureBanner { clipboardHasContent = false }
                }

                if !store.clips.isEmpty {
                    kindFilter
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: Ink.gutter, bottom: 6, trailing: Ink.gutter))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(visible) { clip in
                ClipRow(clip: clip, onDetail: { detail = clip }, onPin: { pinning = clip })
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(Ink.paper)
        .overlay { emptyState }
        .safeAreaInset(edge: .bottom, spacing: 0) { searchBar }
        .animation(.snappy(duration: 0.22), value: visible.map(\.id))
        .sheet(item: $detail) { clip in ClipDetailSheet(clipID: clip.id) }
        .sheet(item: $pinning) { clip in PinSheet(clipID: clip.id) }
        .sheet(isPresented: $showingSettings) { SettingsSheet() }
        .onAppear {
            checkClipboard()
            if LaunchOptions.screen == "detail", detail == nil { detail = store.clips.first { $0.kind == .color } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkClipboard() }
        }
    }

    private var statusLine: String {
        let count = store.clips.count
        return "\(count) \(count == 1 ? "clip" : "clips") \u{00B7} \(store.syncState.label)"
    }

    /// Asking whether the clipboard has content does not trigger the system
    /// paste prompt; only reading it does, and that goes through PasteButton.
    private func checkClipboard() {
        let pasteboard = UIPasteboard.general
        clipboardHasContent = pasteboard.hasStrings || pasteboard.hasURLs || pasteboard.hasImages
    }

    private var kindFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                InkChip(title: "All", count: store.clips.count, isSelected: kind == nil) { kind = nil }
                ForEach(ClipKind.allCases) { option in
                    let count = store.clips.filter { $0.kind == option }.count
                    if count > 0 {
                        InkChip(title: option.plural, dot: option.accent, count: count, isSelected: kind == option) {
                            kind = kind == option ? nil : option
                        }
                    }
                }
            }
            .padding(.horizontal, Ink.gutter)
        }
        .padding(.horizontal, -Ink.gutter)
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.clips.isEmpty {
            VStack(spacing: 22) {
                InkEmptyState(
                    symbol: "clipboard",
                    title: "Your clipboard, kept",
                    message: "Clips you save here, and soon everything you copy on your Mac, will be waiting for you."
                )
                .frame(maxHeight: 260)
                Button("Load sample clips") { store.loadSampleLibrary() }
                    .buttonStyle(InkButtonStyle(prominent: false))
                    .frame(width: 220)
            }
            .padding(.top, 120)
        } else if visible.isEmpty {
            InkEmptyState(
                symbol: "magnifyingglass",
                title: query.isEmpty ? "No \(kind?.plural.lowercased() ?? "clips") yet" : "No matches",
                message: query.isEmpty ? "Choose All to see everything." : "Nothing matches \u{201C}\(query)\u{201D}."
            )
            .padding(.top, 140)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Ink.ink3)
            TextField("Search clips", text: $query)
                .font(.system(size: 16))
                .foregroundStyle(Ink.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Ink.ink2)
                        .frame(width: 28, height: 28)
                        .background(Ink.sunken)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Ink.surface)
        .overlay(Rectangle().strokeBorder(searchFocused ? Ink.ink : Ink.line, lineWidth: searchFocused ? 1.5 : 1))
        .padding(.horizontal, Ink.gutter)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Ink.paper)
    }
}

/// A clip in a list: tap copies, swipe pins or deletes, long-press shows everything.
struct ClipRow: View {
    @EnvironmentObject private var store: ClipStore
    let clip: Clip
    let onDetail: () -> Void
    let onPin: () -> Void

    var body: some View {
        Button {
            store.copy(clip)
        } label: {
            ClipCard(
                clip: clip, pinboards: store.pinboards(containing: clip), image: store.image(for: clip),
                onMore: onDetail)
        }
        .buttonStyle(PressScaleStyle())
        .listRowInsets(EdgeInsets(top: 5, leading: Ink.gutter, bottom: 5, trailing: Ink.gutter))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.delete(clip)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onPin) {
                Label("Pin", systemImage: "pin")
            }
            .tint(Ink.ink2)
        }
        .contextMenu {
            Button {
                store.copy(clip)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            if clip.kind == .link {
                Button {
                    store.copy(clip, plainText: true)
                } label: {
                    Label("Copy as plain text", systemImage: "doc.plaintext")
                }
            }
            Button(action: onPin) {
                Label("Pin to\u{2026}", systemImage: "pin")
            }
            if clip.kind != .image {
                ShareLink(item: clip.content) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            Button(action: onDetail) {
                Label("Details", systemImage: "info.circle")
            }
            Divider()
            Button(role: .destructive) {
                store.delete(clip)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// A press that feels physical without rounding or shadow: the card sinks a hair.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// Offers to save what is on the system clipboard. Uses the system paste
/// button, so iOS never interrupts with its "Allow Paste" alert.
struct CaptureBanner: View {
    @EnvironmentObject private var store: ClipStore
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("On your clipboard now")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Ink.ink)
                Text("Save it to Superclip")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.ink2)
            }
            Spacer()
            PasteButton(supportedContentTypes: [.image, .url, .plainText]) { providers in
                handle(providers)
            }
            .labelStyle(.titleOnly)
            .buttonBorderShape(.roundedRectangle(radius: 0))
            .tint(Ink.ink)

            Button(action: onDone) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Ink.ink2)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .background(Ink.sunken)
        .overlay(alignment: .leading) { Rectangle().fill(Ink.ink).frame(width: 2) }
    }

    private func handle(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        if provider.canLoadObject(ofClass: UIImage.self) {
            _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                Task { @MainActor in
                    store.capture(image: image)
                    onDone()
                }
            }
        } else if provider.canLoadObject(ofClass: String.self) {
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                guard let text else { return }
                Task { @MainActor in
                    store.capture(text: text)
                    onDone()
                }
            }
        }
    }
}
