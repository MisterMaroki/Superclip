//
//  SuperclipApp.swift
//  Superclip
//

import SwiftUI

@main
struct SuperclipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — app runs from menu bar + AppDelegate
        Settings {
            EmptyView()
        }
    }
}
