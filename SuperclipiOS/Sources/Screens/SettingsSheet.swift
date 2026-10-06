//
//  SettingsSheet.swift
//  Superclip for iPhone
//

import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var store: ClipStore
    @EnvironmentObject private var sync: PhoneSync
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingErase = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 28, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(Ink.ink)
                    Spacer()
                    HeaderButton(symbol: "xmark", label: "Close") { dismiss() }
                }

                group("Sync") {
                    Button {
                        sync.isEnabled.toggle()
                    } label: {
                        HStack {
                            Text("Sync with iCloud")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Ink.ink)
                            Spacer()
                            InkSwitch(isOn: sync.isEnabled)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(sync.isEnabled ? .isSelected : [])

                    Rectangle().fill(Ink.line).frame(height: 1)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(store.syncState == .localOnly ? Ink.ink3 : Ink.ink)
                                .frame(width: 8, height: 8)
                            Text(store.syncState.label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Ink.ink)
                        }
                        Text(store.syncDetail)
                            .font(.system(size: 14))
                            .foregroundStyle(Ink.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                group("Library") {
                    DetailRow(label: "Clips", value: "\(store.clips.count)")
                    DetailRow(label: "Pinboards", value: "\(store.pinboards.count)")
                    DetailRow(label: "Snippets", value: "\(store.snippets.count)", isLast: true)
                }

                VStack(spacing: 10) {
                    Button("Load sample clips") {
                        store.loadSampleLibrary()
                        dismiss()
                    }
                    .buttonStyle(InkButtonStyle(prominent: false))

                    Button {
                        confirmingErase = true
                    } label: {
                        Text("Erase everything")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Ink.danger)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .overlay(Rectangle().strokeBorder(Ink.danger.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Text("Superclip \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .inkLabel()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(Ink.gutter)
            .padding(.top, 12)
        }
        .background(Ink.paper)
        .presentationCornerRadius(0)
        .confirmationDialog(
            sync.isEnabled
                ? "Erase every clip, pinboard and snippet? With sync on, they are removed from iCloud and your Mac too."
                : "Erase every clip, pinboard and snippet on this iPhone?",
            isPresented: $confirmingErase, titleVisibility: .visible
        ) {
            Button("Erase everything", role: .destructive) {
                store.eraseEverything()
                dismiss()
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).inkLabel()
            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Ink.surface)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        }
    }
}
