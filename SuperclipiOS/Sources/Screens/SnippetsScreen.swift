//
//  SnippetsScreen.swift
//  Superclip for iPhone
//
//  Snippets: text you type often. On the Mac they expand as you type their
//  trigger; here, tap one to copy it.
//

import SwiftUI

struct SnippetsScreen: View {
    @EnvironmentObject private var store: ClipStore
    @State private var editing: Snippet?
    @State private var creating = false

    var body: some View {
        List {
            ScreenHeader(title: "Snippets", status: "Tap to copy") {
                HeaderButton(symbol: "plus", label: "New snippet") { creating = true }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: Ink.gutter, bottom: 10, trailing: Ink.gutter))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(store.snippets) { snippet in
                Button {
                    store.copy(snippet)
                } label: {
                    SnippetRow(snippet: snippet)
                }
                .buttonStyle(PressScaleStyle())
                .listRowInsets(EdgeInsets(top: 5, leading: Ink.gutter, bottom: 5, trailing: Ink.gutter))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.delete(snippet)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editing = snippet
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(Ink.ink2)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Ink.paper)
        .overlay {
            if store.snippets.isEmpty {
                InkEmptyState(
                    symbol: "text.cursor",
                    title: "Write it once",
                    message: "Save an email address, a reply or a signature, then copy it with one tap."
                )
            }
        }
        .sheet(isPresented: $creating) { SnippetEditor(snippet: nil) }
        .sheet(item: $editing) { snippet in SnippetEditor(snippet: snippet) }
    }
}

struct SnippetRow: View {
    let snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snippet.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Ink.ink)
                Spacer()
                if !snippet.trigger.isEmpty {
                    Text(snippet.trigger)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Ink.ink2)
                        .padding(.horizontal, 7)
                        .frame(height: 24)
                        .background(Ink.sunken)
                        .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 2) }
                }
            }
            Text(snippet.content)
                .font(.system(size: 14))
                .foregroundStyle(Ink.ink2)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Ink.surface)
        .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

struct SnippetEditor: View {
    @EnvironmentObject private var store: ClipStore
    @Environment(\.dismiss) private var dismiss
    let snippet: Snippet?
    @State private var name = ""
    @State private var trigger = ""
    @State private var content = ""

    private var canSave: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(snippet == nil ? "New snippet" : "Edit snippet")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Ink.ink)

            field("Name", text: $name, placeholder: "Email")
            field("Trigger on Mac", text: $trigger, placeholder: ";;mail", mono: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Text").inkLabel()
                TextEditor(text: $content)
                    .font(.system(size: 16))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 110)
                    .background(Ink.surface)
                    .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
            }

            Spacer(minLength: 0)

            Button(snippet == nil ? "Save snippet" : "Save") {
                var updated = snippet ?? Snippet(name: "", trigger: "", content: "")
                updated.name = name.isEmpty ? "Untitled" : name
                updated.trigger = trigger.trimmingCharacters(in: .whitespaces)
                updated.content = content
                store.save(updated)
                dismiss()
            }
            .buttonStyle(InkButtonStyle())
            .opacity(canSave ? 1 : 0.4)
            .disabled(!canSave)
        }
        .padding(Ink.gutter)
        .padding(.top, 14)
        .background(Ink.paper)
        .presentationDetents([.large])
        .presentationCornerRadius(0)
        .onAppear {
            name = snippet?.name ?? ""
            trigger = snippet?.trigger ?? ""
            content = snippet?.content ?? ""
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).inkLabel()
            TextField(placeholder, text: text)
                .font(.system(size: 17, design: mono ? .monospaced : .default))
                .autocorrectionDisabled(mono)
                .textInputAutocapitalization(mono ? .never : .sentences)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Ink.surface)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        }
    }
}
