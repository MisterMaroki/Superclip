//
//  SettingsView.swift
//  Superclip
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Sections

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case shortcuts = "Shortcuts"
    case snippets = "Snippets"
    case privacy = "Privacy"
    case storage = "Storage"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .shortcuts: return "keyboard.fill"
        case .snippets: return "text.insert"
        case .privacy: return "hand.raised.fill"
        case .storage: return "internaldrive.fill"
        case .about: return "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: return .gray
        case .appearance: return .purple
        case .shortcuts: return .orange
        case .snippets: return .cyan
        case .privacy: return .red
        case .storage: return .blue
        case .about: return .green
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var onClose: () -> Void
    @ObservedObject var settings: SettingsManager
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var pinboardManager: PinboardManager
    @ObservedObject var snippetManager: SnippetManager

    @State private var selectedSection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
                .frame(width: 200)

            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1)

            // Detail pane
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 480)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Sidebar

    var sidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header with close button and title
            HStack(spacing: 8) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close settings")

                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.9))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            // Section list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsSidebarItem(
                            section: section,
                            isSelected: selectedSection == section,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedSection = section
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .background(Color.primary.opacity(0.05))
    }

    // MARK: - Detail Pane

    @ViewBuilder
    var detailPane: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsPane(settings: settings)
        case .appearance:
            AppearanceSettingsPane(settings: settings)
        case .shortcuts:
            ShortcutsSettingsPane(settings: settings)
        case .snippets:
            SnippetsSettingsPane(snippetManager: snippetManager)
        case .privacy:
            PrivacySettingsPane(settings: settings)
        case .storage:
            StorageSettingsPane(
                settings: settings,
                clipboardManager: clipboardManager,
                pinboardManager: pinboardManager
            )
        case .about:
            AboutSettingsPane()
        }
    }
}

// MARK: - Sidebar Item

struct SettingsSidebarItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 10) {
                // Icon with colored background
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(section.iconColor)
                    )

                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary.opacity(isSelected ? 1.0 : 0.8))

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.primary.opacity(0.15) : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Setting Row Components

struct SettingsGroupBox<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 1) {
                content()
            }
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.95))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct SettingsPickerRow<T: Hashable & CustomStringConvertible>: View {
    let title: String
    let options: [T]
    @Binding var selection: T

    init(title: String, options: [T], selection: Binding<T>) {
        self.title = title
        self.options = options
        self._selection = selection
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.95))

            Spacer()

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.description).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct SettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.95))

            Spacer()

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct SettingsButtonRow: View {
    let title: String
    let subtitle: String?
    let buttonTitle: String
    let action: () -> Void

    init(title: String, subtitle: String? = nil, buttonTitle: String, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.95))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }

            Spacer()

            Button {
                action()
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.95))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct SettingsShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.95))

            Spacer()

            Text(shortcut)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 12)
    }
}

// MARK: - General Settings Pane

struct GeneralSettingsPane: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Pane title
                Text("General")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 4)

                SettingsGroupBox(title: "Startup") {
                    SettingsToggleRow(
                        title: "Launch at login",
                        subtitle: "Start Superclip when you log in",
                        isOn: $settings.launchAtLogin
                    )
                }

                SettingsGroupBox(title: "Clipboard") {
                    SettingsToggleRow(
                        title: "Monitor clipboard",
                        subtitle: "Automatically capture clipboard changes",
                        isOn: $settings.monitorClipboard
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Deduplicate items",
                        subtitle: "Avoid saving duplicate clipboard entries",
                        isOn: $settings.deduplicateItems
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Detect links",
                        subtitle: "Fetch metadata for copied URLs",
                        isOn: $settings.detectLinks
                    )
                }

                SettingsGroupBox(title: "Behavior") {
                    SettingsToggleRow(
                        title: "Paste after selecting",
                        subtitle: "Automatically paste when selecting an item",
                        isOn: $settings.pasteAfterSelecting
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Play sound effects",
                        isOn: $settings.playSoundEffects
                    )
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Appearance Settings Pane

struct AppearanceSettingsPane: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Appearance")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 4)

                SettingsGroupBox(title: "Window") {
                    SettingsToggleRow(
                        title: "Show item count",
                        subtitle: "Display number of items in the header",
                        isOn: $settings.showItemCount
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Show source app icons",
                        subtitle: "Display which app copied the item",
                        isOn: $settings.showSourceAppIcons
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Show timestamps",
                        subtitle: "Display when items were copied",
                        isOn: $settings.showTimestamps
                    )
                }

                SettingsGroupBox(title: "Preview") {
                    SettingsToggleRow(
                        title: "Show link previews",
                        subtitle: "Fetch and display thumbnails for URLs",
                        isOn: $settings.showLinkPreviews
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Syntax highlighting",
                        subtitle: "Highlight code snippets in preview",
                        isOn: $settings.syntaxHighlighting
                    )
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Shortcuts Settings Pane

struct ShortcutsSettingsPane: View {
    @ObservedObject var settings: SettingsManager

    @State private var historyConfig: HotkeyConfig = .defaultHistory
    @State private var pasteStackConfig: HotkeyConfig = .defaultPasteStack
    @State private var ocrConfig: HotkeyConfig = .defaultOCR

    var allConfigs: [HotkeyConfig] {
        [historyConfig, pasteStackConfig, ocrConfig]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Shortcuts")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 4)

                SettingsGroupBox(title: "Global Hotkeys") {
                    HotkeyRecorderView(
                        title: "Open clipboard history",
                        config: $historyConfig,
                        allConfigs: allConfigs,
                        onChanged: { settings.historyHotkey = historyConfig.dictionary }
                    )
                    SettingsDivider()
                    HotkeyRecorderView(
                        title: "Open paste stack",
                        config: $pasteStackConfig,
                        allConfigs: allConfigs,
                        onChanged: { settings.pasteStackHotkey = pasteStackConfig.dictionary }
                    )
                    SettingsDivider()
                    HotkeyRecorderView(
                        title: "Screen capture OCR",
                        config: $ocrConfig,
                        allConfigs: allConfigs,
                        onChanged: { settings.ocrHotkey = ocrConfig.dictionary }
                    )
                    SettingsDivider()
                    HStack {
                        Spacer()
                        Button {
                            settings.resetHotkeysToDefaults()
                            historyConfig = .defaultHistory
                            pasteStackConfig = .defaultPasteStack
                            ocrConfig = .defaultOCR
                        } label: {
                            Text("Reset to Defaults")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.08))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                SettingsGroupBox(title: "Navigation") {
                    SettingsShortcutRow(title: "Navigate items", shortcut: "\u{2190} \u{2192}")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Select item", shortcut: "\u{21A9}")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Toggle preview", shortcut: "Space")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Delete item", shortcut: "\u{232B}")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Undo delete", shortcut: "\u{2318}Z")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Search", shortcut: "/")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Navigate pinboards", shortcut: "\u{2318}\u{2190} \u{2318}\u{2192}")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Quick select", shortcut: "\u{2318}1-9")
                }
            }
            .padding(24)
        }
        .onAppear {
            historyConfig = settings.hotkeyConfigForHistory()
            pasteStackConfig = settings.hotkeyConfigForPasteStack()
            ocrConfig = settings.hotkeyConfigForOCR()
        }
    }
}

// MARK: - Privacy Settings Pane

struct PrivacySettingsPane: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 4)

                SettingsGroupBox(title: "Content Filtering") {
                    SettingsToggleRow(
                        title: "Ignore confidential content",
                        subtitle: "Do not save passwords and sensitive data when detected",
                        isOn: $settings.ignoreConfidentialContent
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Ignore transient content",
                        subtitle: "Do not save temporary data generated by other apps",
                        isOn: $settings.ignoreTransientContent
                    )
                }

                IgnoredAppsSection(settings: settings)
            }
            .padding(24)
        }
    }
}

// MARK: - Ignored Apps Section

struct IgnoredAppInfo: Identifiable {
    let id: String // bundle identifier
    let name: String
    let icon: NSImage?
}

struct IgnoredAppsSection: View {
    @ObservedObject var settings: SettingsManager
    @State private var selectedAppID: String?
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IGNORED APPLICATIONS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.6))
                .tracking(0.5)

            Text("Do not save content copied from the applications below.")
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.5))

            VStack(spacing: 0) {
                appListContent

                SettingsDivider()

                appListToolbar
            }
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .popover(isPresented: $showingAppPicker, arrowEdge: .bottom) {
            InstalledAppPickerView(settings: settings, isPresented: $showingAppPicker)
        }
    }

    @ViewBuilder
    private var appListContent: some View {
        let apps = resolveApps()
        if apps.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(apps) { app in
                        appRow(app)
                        if app.id != apps.last?.id {
                            SettingsDivider()
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
    }

    private func resolveApps() -> [IgnoredAppInfo] {
        settings.ignoredAppBundleIDs.map { bundleID in
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                return IgnoredAppInfo(id: bundleID, name: bundleID, icon: nil)
            }
            let name = Bundle(url: appURL)?
                .object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle(url: appURL)?
                    .object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? appURL.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return IgnoredAppInfo(id: bundleID, name: name, icon: icon)
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 24))
                    .foregroundStyle(.primary.opacity(0.25))
                Text("No ignored applications")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.4))
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }

    private func appRow(_ app: IgnoredAppInfo) -> some View {
        HStack(spacing: 10) {
            appIcon(app)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.95))
                Text(app.id)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.4))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selectedAppID == app.id ? Color.accentColor.opacity(0.3) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedAppID = selectedAppID == app.id ? nil : app.id
        }
    }

    @ViewBuilder
    private func appIcon(_ app: IgnoredAppInfo) -> some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 24, height: 24)
                .cornerRadius(5)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 18))
                .foregroundStyle(.primary.opacity(0.4))
                .frame(width: 24, height: 24)
        }
    }

    private var appListToolbar: some View {
        HStack(spacing: 0) {
            Button {
                showingAppPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(width: 36, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 18)
                .background(Color.primary.opacity(0.1))

            Button {
                if let id = selectedAppID {
                    settings.removeIgnoredApp(id)
                    selectedAppID = nil
                }
            } label: {
                let opacity: Double = selectedAppID != nil ? 0.7 : 0.25
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(opacity))
                    .frame(width: 36, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(selectedAppID == nil)

            Spacer()
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
    }
}

// MARK: - Installed App Picker (popover)

private struct InstalledAppPickerView: View {
    @ObservedObject var settings: SettingsManager
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var installedApps: [IgnoredAppInfo] = []

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            appList
        }
        .frame(width: 280, height: 320)
        .onAppear { loadInstalledApps() }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search applications", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(8)
    }

    private var filteredApps: [IgnoredAppInfo] {
        let excluded = Set(settings.ignoredAppBundleIDs)
        let available = installedApps.filter { !excluded.contains($0.id) }
        if searchText.isEmpty { return available }
        let query = searchText.lowercased()
        return available.filter {
            $0.name.lowercased().contains(query) || $0.id.lowercased().contains(query)
        }
    }

    private var appList: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(filteredApps) { app in
                    pickerRow(app)
                }
            }
        }
    }

    private func pickerRow(_ app: IgnoredAppInfo) -> some View {
        Button {
            settings.addIgnoredApp(app.id)
            isPresented = false
        } label: {
            HStack(spacing: 8) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }

                Text(app.name)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadInstalledApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var apps: [IgnoredAppInfo] = []
            let dirs = ["/Applications", "/System/Applications"]
            for dir in dirs {
                guard let urls = try? fm.contentsOfDirectory(
                    at: URL(fileURLWithPath: dir),
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }
                for url in urls where url.pathExtension == "app" {
                    guard let bundle = Bundle(url: url),
                          let bundleID = bundle.bundleIdentifier else { continue }
                    let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? url.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    apps.append(IgnoredAppInfo(id: bundleID, name: name, icon: icon))
                }
            }
            apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async {
                installedApps = apps
            }
        }
    }
}

// MARK: - Storage Settings Pane

struct StorageSettingsPane: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var pinboardManager: PinboardManager

    @State private var showClearHistoryAlert = false
    @State private var showClearPinboardsAlert = false
    @State private var showExportAlert = false
    @State private var showImportAlert = false

    private let historySizeOptions = [0, 25, 50, 100, 200, 500]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Storage")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 4)

                SettingsGroupBox(title: "History") {
                    HStack {
                        Text("Max history size")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.95))

                        Spacer()

                        Picker("", selection: $settings.maxHistorySize) {
                            ForEach(historySizeOptions, id: \.self) { option in
                                Text(option == 0 ? "Unlimited" : "\(option)").tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    SettingsDivider()
                    SettingsInfoRow(title: "Items stored", value: "\(clipboardManager.history.count) items")
                    SettingsDivider()
                    SettingsInfoRow(title: "Pinned items", value: "\(pinboardManager.totalPinnedItemCount) items")
                }

                SettingsGroupBox(title: "Data") {
                    SettingsButtonRow(
                        title: "Clear clipboard history",
                        subtitle: "Remove all items from history",
                        buttonTitle: "Clear",
                        action: { showClearHistoryAlert = true }
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Clear pinboards",
                        subtitle: "Remove all pinned items",
                        buttonTitle: "Clear",
                        action: { showClearPinboardsAlert = true }
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Export data",
                        subtitle: "Export history and pins to a file",
                        buttonTitle: "Export",
                        action: { showExportAlert = true }
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Import data",
                        subtitle: "Restore from an exported file",
                        buttonTitle: "Import",
                        action: { showImportAlert = true }
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Clear on quit",
                        subtitle: "Erase history when Superclip quits",
                        isOn: $settings.clearOnQuit
                    )
                }
            }
            .padding(24)
        }
        .alert("Clear History", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clipboardManager.clearHistory()
            }
        } message: {
            Text("This will remove all \(clipboardManager.history.count) items from your clipboard history. This cannot be undone.")
        }
        .alert("Clear Pinboards", isPresented: $showClearPinboardsAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                pinboardManager.clearAllPinboards()
            }
        } message: {
            Text("This will remove all pinned items from every pinboard. This cannot be undone.")
        }
        .alert("Export Not Available", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Export functionality is coming in a future update.")
        }
        .alert("Import Not Available", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Import functionality is coming in a future update.")
        }
    }
}

// MARK: - About Settings Pane

struct AboutSettingsPane: View {
    @State private var showUpToDateAlert = false
    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // App icon
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                } else {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 80, height: 80)
                }

                // App name
                Text("Superclip")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                // Version
                Text("Version \(appVersion)")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.55))

                // Description
                Text("A modern clipboard manager for macOS")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.45))
                    .padding(.top, 4)
            }

            Spacer()

            // Footer links
            VStack(spacing: 12) {
                SettingsGroupBox(title: "") {
                    SettingsButtonRow(
                        title: "Check for updates",
                        buttonTitle: "Check",
                        action: { showUpToDateAlert = true }
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Rate on App Store",
                        buttonTitle: "Rate",
                        action: {
                            // Replace with actual App Store ID when available
                            if let url = URL(string: "macappstore://apps.apple.com/app/id0000000000?action=write-review") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Send feedback",
                        buttonTitle: "Email",
                        action: {
                            if let url = URL(string: "mailto:feedback@superclip.app?subject=Superclip%20Feedback") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Quit buttons
            HStack(spacing: 10) {
                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .medium))
                        Text("Quit Superclip")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showResetAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .medium))
                        Text("Quit & Reset")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 24)
        }
        .alert("Up to Date", isPresented: $showUpToDateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You're running the latest version of Superclip.")
        }
        .alert("Reset Superclip?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Quit & Reset", role: .destructive) {
                SettingsManager.resetAllUserDefaults()
                NSApp.terminate(nil)
            }
        } message: {
            Text("This will erase all settings, clipboard history, and pinboards, then quit the app. The next launch will start fresh with onboarding.")
        }
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Snippets Settings Pane

struct SnippetsSettingsPane: View {
    @ObservedObject var snippetManager: SnippetManager

    @State private var selectedSnippetId: UUID?
    @State private var isCreating = false
    @State private var editName = ""
    @State private var editTrigger = ""
    @State private var editContent = ""
    @State private var editError: String?

    var selectedSnippet: Snippet? {
        guard let id = selectedSnippetId else { return nil }
        return snippetManager.snippets.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Snippet list (left)
            snippetList
                .frame(width: 220)

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)

            // Detail editor (right)
            if isCreating || selectedSnippet != nil {
                snippetEditor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Snippet List

    var snippetList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Snippets")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Text("\(snippetManager.enabledSnippetCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(snippetManager.snippets) { snippet in
                        snippetRow(snippet)
                    }
                }
                .padding(.horizontal, 8)
            }

            // Toolbar
            HStack(spacing: 0) {
                Button {
                    isCreating = true
                    selectedSnippetId = nil
                    editName = ""
                    editTrigger = ";;"
                    editContent = ""
                    editError = nil
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 16)

                Button {
                    if let id = selectedSnippetId, let snippet = snippetManager.snippets.first(where: { $0.id == id }) {
                        snippetManager.deleteSnippet(snippet)
                        selectedSnippetId = nil
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(selectedSnippetId != nil ? 0.7 : 0.25))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(selectedSnippetId == nil)

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04))
        }
    }

    func snippetRow(_ snippet: Snippet) -> some View {
        Button {
            selectedSnippetId = snippet.id
            isCreating = false
            editName = snippet.name
            editTrigger = snippet.trigger
            editContent = snippet.content
            editError = nil
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(snippet.isEnabled ? Color.cyan : Color.primary.opacity(0.2))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.name.isEmpty ? "Untitled" : snippet.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.9))
                        .lineLimit(1)

                    Text(snippet.trigger)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.45))
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedSnippetId == snippet.id ? Color.primary.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Snippet Editor

    var snippetEditor: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(isCreating ? "New Snippet" : "Edit Snippet")
                    .font(.system(size: 16, weight: .semibold))

                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.5))
                        .textCase(.uppercase)

                    TextField("e.g., Email address", text: $editName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                // Trigger
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trigger")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.5))
                        .textCase(.uppercase)

                    TextField("e.g., ;;email", text: $editTrigger)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))

                    Text("Type this anywhere to expand the snippet")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.35))
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Content")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.5))
                        .textCase(.uppercase)

                    TextEditor(text: $editContent)
                        .font(.system(size: 13))
                        .frame(minHeight: 100, maxHeight: 200)
                        .padding(4)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }

                if let error = editError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                }

                // Actions
                HStack {
                    if !isCreating, let snippet = selectedSnippet {
                        Button {
                            snippetManager.toggleSnippet(snippet)
                        } label: {
                            Text(snippet.isEnabled ? "Disable" : "Enable")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.08))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        saveSnippet()
                    } label: {
                        Text(isCreating ? "Create" : "Save")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.insert")
                .font(.system(size: 32))
                .foregroundStyle(.primary.opacity(0.2))

            Text("Select a snippet or create a new one")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.4))

            Text("Type a trigger shortcut anywhere to auto-expand text")
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.25))
        }
    }

    // MARK: - Save

    private func saveSnippet() {
        let trimmedTrigger = editTrigger.trimmingCharacters(in: .whitespaces)
        let trimmedContent = editContent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTrigger.isEmpty else {
            editError = "Trigger cannot be empty"
            return
        }

        guard trimmedTrigger.count >= 2 else {
            editError = "Trigger must be at least 2 characters"
            return
        }

        guard !trimmedContent.isEmpty else {
            editError = "Content cannot be empty"
            return
        }

        let excludeId = isCreating ? nil : selectedSnippetId
        if snippetManager.isTriggerTaken(trimmedTrigger, excludingId: excludeId) {
            editError = "This trigger is already used by another snippet"
            return
        }

        editError = nil

        if isCreating {
            let snippet = snippetManager.createSnippet(
                name: editName.trimmingCharacters(in: .whitespaces),
                trigger: trimmedTrigger,
                content: trimmedContent
            )
            selectedSnippetId = snippet.id
            isCreating = false
        } else if var snippet = selectedSnippet {
            snippet.name = editName.trimmingCharacters(in: .whitespaces)
            snippet.trigger = trimmedTrigger
            snippet.content = trimmedContent
            snippetManager.updateSnippet(snippet)
        }
    }
}
