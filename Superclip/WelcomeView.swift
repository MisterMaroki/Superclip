//
//  WelcomeView.swift
//  Superclip
//

import SwiftUI

struct WelcomeView: View {
    var onDismiss: () -> Void
    var onOpenAccessibility: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Welcome to Superclip")
                .font(.title2.bold())

            Text("Superclip runs from your menu bar (clipboard icon). Use it to browse and reuse everything you copy.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "command")
                    Text("Press **⌘⇧V** anywhere to open the clipboard drawer")
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "menubar.rectangle")
                    Text("Or click the menu bar icon → **Show Superclip**")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Text("If ⌘⇧V doesn't work, Superclip needs Accessibility access to listen for the shortcut.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Accessibility Settings") {
                onOpenAccessibility()
            }
            .buttonStyle(.borderedProminent)

            Button("Got it") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 400)
    }
}
