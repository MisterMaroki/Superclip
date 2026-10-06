//
//  SuperclipApp.swift
//  Superclip for iPhone
//

import SwiftUI

@main
struct SuperclipApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model.store)
                .environmentObject(model.sync)
                .tint(Ink.ink)
                .preferredColorScheme(LaunchOptions.colorScheme)
                .onAppear {
                    if LaunchOptions.wantsSampleData { model.store.loadSampleLibrary() }
                    // Sample-data runs are for screenshots: keep them off iCloud
                    if !LaunchOptions.wantsSampleData { model.sync.start() }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    // Coming to the front is when stale data would be noticed
                    model.store.importSharedInbox()
                    model.sync.refresh()
                }
        }
    }
}

/// The app's long-lived objects.
@MainActor
final class AppModel: ObservableObject {
    let store: ClipStore
    let sync: PhoneSync

    init() {
        let store = ClipStore()
        self.store = store
        self.sync = PhoneSync(store: store)
    }
}

/// Launch arguments used for screenshots and UI review:
///   -sampleData 1            load the sample library
///   -appearance dark|light   force an appearance
///   -screen pinboards|snippets|detail|settings|search|empty
enum LaunchOptions {
    private static let defaults = UserDefaults.standard

    static var wantsSampleData: Bool { defaults.bool(forKey: "sampleData") }

    static var colorScheme: ColorScheme? {
        switch defaults.string(forKey: "appearance") {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    static var screen: String? { defaults.string(forKey: "screen") }
}

struct RootView: View {
    @EnvironmentObject private var store: ClipStore
    @State private var tab: Tab = LaunchOptions.screen.flatMap(Tab.init(rawValue:)) ?? .clipboard

    enum Tab: String {
        case clipboard, pinboards, snippets
    }

    var body: some View {
        TabView(selection: $tab) {
            HistoryScreen()
                .tabItem { Label("Clipboard", systemImage: "clipboard") }
                .tag(Tab.clipboard)
            PinboardsScreen()
                .tabItem { Label("Pinboards", systemImage: "pin") }
                .tag(Tab.pinboards)
            SnippetsScreen()
                .tabItem { Label("Snippets", systemImage: "text.cursor") }
                .tag(Tab.snippets)
        }
        .overlay(alignment: .bottom) { toastLayer }
        .sensoryFeedback(.success, trigger: store.toast?.id)
    }

    @ViewBuilder
    private var toastLayer: some View {
        if let toast = store.toast {
            InkToast(
                text: toast.text,
                actionTitle: toast.undo == nil ? nil : "Undo",
                action: toast.undo.map { undo in { store.perform(undo) } }
            )
            .padding(.bottom, 118)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
            .task(id: toast.id) {
                // Long enough to read; longer when there is something to undo
                try? await Task.sleep(for: .seconds(toast.undo == nil ? 1.8 : 4.5))
                if store.toast?.id == toast.id {
                    withAnimation(.snappy(duration: 0.2)) { store.toast = nil }
                }
            }
        }
    }
}

/// Large screen title with an optional line of status beneath, shared by the three tabs.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var status: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(Ink.ink)
                if let status {
                    Text(status).inkLabel()
                }
            }
            Spacer()
            trailing
        }
        .padding(.top, 8)
    }
}

/// Square icon button used in screen headers.
struct HeaderButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Ink.ink)
                .frame(width: 40, height: 40)
                .background(Ink.surface)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
