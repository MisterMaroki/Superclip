//
//  PinboardsScreen.swift
//  Superclip for iPhone
//
//  Pinboards: the clips you chose to keep, grouped your way.
//

import SwiftUI

struct PinboardsScreen: View {
    @EnvironmentObject private var store: ClipStore
    @State private var editing: Pinboard?
    @State private var creating = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Pinboards", status: "\(store.pinboards.count) boards") {
                        HeaderButton(symbol: "plus", label: "New pinboard") { creating = true }
                    }

                    if store.pinboards.isEmpty {
                        InkEmptyState(
                            symbol: "pin",
                            title: "Keep what matters",
                            message: "A pinboard holds clips you want to keep around. Swipe a clip to the right to pin it."
                        )
                        .frame(height: 360)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(store.pinboards) { board in
                                NavigationLink(value: board.id) {
                                    PinboardTile(board: board, clips: store.clips(in: board, kind: nil, matching: ""))
                                }
                                .buttonStyle(PressScaleStyle())
                                .contextMenu {
                                    Button {
                                        editing = board
                                    } label: {
                                        Label("Rename or recolor", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        store.delete(board)
                                    } label: {
                                        Label("Delete pinboard", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Ink.gutter)
                .padding(.vertical, 6)
            }
            .background(Ink.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                PinboardDetailScreen(boardID: id)
            }
            .sheet(isPresented: $creating) { PinboardEditor(board: nil) }
            .sheet(item: $editing) { board in PinboardEditor(board: board) }
        }
    }
}

struct PinboardTile: View {
    let board: Pinboard
    let clips: [Clip]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(board.tint.color).frame(height: 3)
            VStack(alignment: .leading, spacing: 8) {
                Text(board.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Ink.ink)
                    .lineLimit(1)
                Text("\(clips.count) \(clips.count == 1 ? "clip" : "clips")")
                    .inkMeta()

                Spacer(minLength: 6)

                // A glimpse of what's inside: colour clips as swatches, the rest as lines
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(clips.prefix(3)) { clip in
                        if clip.kind == .color, let rgb = ClipClassifier.rgb(from: clip.content) {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                                    .frame(width: 12, height: 12)
                                    .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
                                Text(clip.displayText.uppercased()).inkMeta()
                            }
                        } else {
                            Text(clip.title ?? clip.displayText)
                                .font(.system(size: 12))
                                .foregroundStyle(Ink.ink2)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        }
        .background(Ink.surface)
        .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

struct PinboardDetailScreen: View {
    @EnvironmentObject private var store: ClipStore
    @Environment(\.dismiss) private var dismiss
    let boardID: UUID
    @State private var detail: Clip?
    @State private var pinning: Clip?

    var body: some View {
        if let board = store.pinboards.first(where: { $0.id == boardID }) {
            let clips = store.clips(in: board, kind: nil, matching: "")
            List {
                ScreenHeader(title: board.name, status: "\(clips.count) pinned") {
                    HeaderButton(symbol: "chevron.left", label: "Back") { dismiss() }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: Ink.gutter, bottom: 10, trailing: Ink.gutter))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                ForEach(clips) { clip in
                    ClipRow(clip: clip, onDetail: { detail = clip }, onPin: { pinning = clip })
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Ink.paper)
            .overlay {
                if clips.isEmpty {
                    InkEmptyState(symbol: "pin", title: "Nothing pinned here", message: "Swipe a clip to the right and choose \(board.name).")
                }
            }
            .overlay(alignment: .top) { Rectangle().fill(board.tint.color).frame(height: 3).ignoresSafeArea(edges: .horizontal) }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $detail) { clip in ClipDetailSheet(clipID: clip.id) }
            .sheet(item: $pinning) { clip in PinSheet(clipID: clip.id) }
        }
    }
}

struct PinboardEditor: View {
    @EnvironmentObject private var store: ClipStore
    @Environment(\.dismiss) private var dismiss
    let board: Pinboard?
    @State private var name = ""
    @State private var tint: PinTint = .orange
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(board == nil ? "New pinboard" : "Edit pinboard")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Ink.ink)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name").inkLabel()
                TextField("Reading list", text: $name)
                    .font(.system(size: 17))
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Ink.surface)
                    .overlay(Rectangle().strokeBorder(focused ? Ink.ink : Ink.line, lineWidth: focused ? 1.5 : 1))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color").inkLabel()
                HStack(spacing: 8) {
                    ForEach(PinTint.allCases) { option in
                        Button {
                            tint = option
                        } label: {
                            Rectangle()
                                .fill(option.color)
                                .frame(height: 34)
                                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: tint == option ? 2.5 : 0).padding(-4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.rawValue)
                        .accessibilityAddTraits(tint == option ? .isSelected : [])
                    }
                }
                .padding(4)
            }

            Spacer(minLength: 0)

            Button(board == nil ? "Create pinboard" : "Save") {
                if var existing = board {
                    existing.name = name.isEmpty ? existing.name : name
                    existing.tint = tint
                    store.update(existing)
                } else {
                    store.addPinboard(name: name, tint: tint)
                }
                dismiss()
            }
            .buttonStyle(InkButtonStyle())
        }
        .padding(Ink.gutter)
        .padding(.top, 14)
        .background(Ink.paper)
        .presentationDetents([.height(340)])
        .presentationCornerRadius(0)
        .onAppear {
            name = board?.name ?? ""
            tint = board?.tint ?? .orange
            focused = board == nil
        }
    }
}
