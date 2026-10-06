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
    case screenCapture = "Screen Capture"
    case snippets = "Snippets"
    case privacy = "Privacy"
    case storage = "Storage"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "circle.lefthalf.filled"
        case .shortcuts: return "command"
        case .screenCapture: return "viewfinder"
        case .snippets: return "text.cursor"
        case .privacy: return "lock"
        case .storage: return "archivebox"
        case .about: return "info"
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
            sidebar
                .frame(width: 180)

            Rectangle()
                .fill(Brand.gray300)
                .frame(width: 1)

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 480)
        .background(Brand.white)
        .overlay(
            Rectangle()
                .stroke(Brand.gray300, lineWidth: 1)
        )
    }

    // MARK: - Sidebar

    var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Brand.gray500)
                        .frame(width: 20, height: 20)
                        .background(Brand.gray200)
                }
                .buttonStyle(.plain)
                .help("Close settings")

                Spacer()

                Text("SETTINGS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Brand.gray500)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            Rectangle()
                .fill(Brand.gray200)
                .frame(height: 1)

            // Section list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsSidebarItem(
                            section: section,
                            isSelected: selectedSection == section,
                            onSelect: {
                                selectedSection = section
                            }
                        )
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(Brand.gray100)
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
        case .screenCapture:
            ScreenCaptureSettingsPane(settings: settings)
        case .snippets:
            SnippetsSettingsPane(snippetManager: snippetManager)
        case .privacy:
            PrivacySettingsPane(settings: settings)
        case .storage:
            StorageSettingsPane(
                settings: settings,
                clipboardManager: clipboardManager,
                pinboardManager: pinboardManager,
                snippetManager: snippetManager
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
            HStack(spacing: 0) {
                // Left accent bar
                Rectangle()
                    .fill(isSelected ? Brand.black : Color.clear)
                    .frame(width: 2)

                HStack(spacing: 8) {
                    Image(systemName: section.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Brand.black : Brand.gray500)
                        .frame(width: 16)

                    Text(section.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Brand.black : Brand.gray600)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(isSelected ? Brand.white : (isHovered ? Brand.gray200 : Color.clear))
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
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Brand.gray500)
                    .tracking(1.5)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 0) {
                content()
            }
            .overlay(
                Rectangle()
                    .stroke(Brand.gray200, lineWidth: 1)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Brand.black)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Brand.gray500)
                }
            }

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(BrandSwitchStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Brand.white)
    }
}

/// The app's switch: square track, square thumb, ink when on. Replaces the
/// system switch scaled to 75% (which kept its unscaled layout box, sat a few
/// points off the right edge, and was the one rounded control in a square UI).
struct BrandSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Rectangle()
                    .fill(configuration.isOn ? Brand.black : Brand.gray300)
                    .frame(width: 32, height: 18)
                Rectangle()
                    .fill(Brand.white)
                    .frame(width: 12, height: 12)
                    .padding(3)
            }
            .animation(.snappy(duration: 0.16), value: configuration.isOn)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Brand.black)

            Spacer()

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.description).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Brand.white)
    }
}

struct SettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Brand.black)

            Spacer()

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Brand.gray500)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Brand.white)
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

    @State private var isButtonHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Brand.black)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Brand.gray500)
                }
            }

            Spacer()

            Button {
                action()
            } label: {
                Text(buttonTitle.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(isButtonHovered ? Brand.white : Brand.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(isButtonHovered ? Brand.black : Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(Brand.black, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in isButtonHovered = hovering }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Brand.white)
    }
}

struct SettingsShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Brand.black)

            Spacer()

            Text(shortcut)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Brand.gray700)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Brand.gray100)
                .overlay(
                    Rectangle()
                        .stroke(Brand.gray300, lineWidth: 1)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Brand.white)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Brand.gray200)
            .frame(height: 1)
    }
}

// MARK: - General Settings Pane

struct GeneralSettingsPane: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("General")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Brand.black)

                SettingsGroupBox(title: "Startup") {
                    SettingsToggleRow(
                        title: "Launch at login",
                        subtitle: "Start Superclip when you log in",
                        isOn: $settings.launchAtLogin
                    )
                }

                // Only in builds signed for iCloud: a switch that can't do
                // anything has no business being in Settings
                if CloudSyncEngine.isEntitled {
                    SyncSettingsGroup(settings: settings)
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
            .padding(28)
        }
    }
}

/// iCloud sync: the switch, and a line saying what state sync is in.
struct SyncSettingsGroup: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        SettingsGroupBox(title: "iCloud") {
            SettingsToggleRow(
                title: "Sync with iCloud",
                subtitle: "Keep clips, pinboards and snippets in step with Superclip on your iPhone",
                isOn: $settings.syncEnabled
            )
            if settings.syncEnabled {
                SettingsDivider()
                if let coordinator = MacSyncCoordinator.current {
                    SyncStatusRow(coordinator: coordinator)
                } else {
                    SettingsInfoRow(title: "Status", value: "Starting\u{2026}")
                }
            }
        }
    }
}

private struct SyncStatusRow: View {
    @ObservedObject var coordinator: MacSyncCoordinator

    var body: some View {
        SettingsInfoRow(title: "Status", value: coordinator.status.label)
    }
}

// MARK: - Appearance Settings Pane

struct AppearanceSettingsPane: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Appearance")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Brand.black)

                SettingsGroupBox(title: "Theme") {
                    HStack {
                        Text("Appearance")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Brand.black)

                        Spacer()

                        Picker("", selection: $settings.theme) {
                            Text("System").tag("System")
                            Text("Light").tag("Light")
                            Text("Dark").tag("Dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Brand.white)
                }

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
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Show keyboard hints",
                        subtitle: "A strip of shortcuts along the bottom of the drawer",
                        isOn: $settings.showKeyboardHints
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
            .padding(28)
        }
    }
}

// MARK: - Shortcuts Settings Pane

struct ShortcutsSettingsPane: View {
    @ObservedObject var settings: SettingsManager

    @State private var historyConfig: HotkeyConfig = .defaultHistory
    @State private var pasteStackConfig: HotkeyConfig = .defaultPasteStack
    @State private var ocrConfig: HotkeyConfig = .defaultOCR
    @State private var screenshotConfig: HotkeyConfig = .defaultScreenshot
    @State private var fullscreenScreenshotConfig: HotkeyConfig = .defaultFullscreenScreenshot

    var allConfigs: [HotkeyConfig] {
        [historyConfig, pasteStackConfig, ocrConfig, screenshotConfig, fullscreenScreenshotConfig]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Shortcuts")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Brand.black)

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
                        title: "Text Sniper (OCR)",
                        config: $ocrConfig,
                        allConfigs: allConfigs,
                        onChanged: { settings.ocrHotkey = ocrConfig.dictionary }
                    )
                    SettingsDivider()
                    HotkeyRecorderView(
                        title: "Take screenshot",
                        config: $screenshotConfig,
                        allConfigs: allConfigs,
                        onChanged: { settings.screenshotHotkey = screenshotConfig.dictionary }
                    )
                    SettingsDivider()
                    HotkeyRecorderView(
                        title: "Capture full screen",
                        config: $fullscreenScreenshotConfig,
                        allConfigs: allConfigs,
                        onChanged: { settings.fullscreenScreenshotHotkey = fullscreenScreenshotConfig.dictionary }
                    )
                    SettingsDivider()
                    HStack {
                        Spacer()
                        Button {
                            settings.resetHotkeysToDefaults()
                            historyConfig = .defaultHistory
                            pasteStackConfig = .defaultPasteStack
                            ocrConfig = .defaultOCR
                            screenshotConfig = .defaultScreenshot
                            fullscreenScreenshotConfig = .defaultFullscreenScreenshot
                        } label: {
                            Text("RESET")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.5)
                                .foregroundStyle(Brand.gray600)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .overlay(
                                    Rectangle()
                                        .stroke(Brand.gray300, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Brand.white)
                }

                SettingsGroupBox(title: "Navigation") {
                    SettingsShortcutRow(title: "Move between items", shortcut: "\u{2190} \u{2192}")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Paste item", shortcut: "\u{21A9}")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Paste as plain text", shortcut: "\u{21E7}\u{21A9}")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Copy without closing", shortcut: "\u{2318}C")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Preview", shortcut: "Space")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Edit text", shortcut: "Hold Space")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Delete item", shortcut: "\u{232B}")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Undo delete", shortcut: "\u{2318}Z")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Search", shortcut: "Just type")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Switch pinboard", shortcut: "\u{2318}\u{2190} \u{2318}\u{2192}")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Quick paste", shortcut: "\u{2318}1\u{2013}9, \u{2318}0")
                }
            }
            .padding(28)
        }
        .onAppear {
            historyConfig = settings.hotkeyConfigForHistory()
            pasteStackConfig = settings.hotkeyConfigForPasteStack()
            ocrConfig = settings.hotkeyConfigForOCR()
            screenshotConfig = settings.hotkeyConfigForScreenshot()
            fullscreenScreenshotConfig = settings.hotkeyConfigForFullscreenScreenshot()
        }
    }
}

// MARK: - Screen Capture Settings Pane

struct ScreenCaptureSettingsPane: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Screen Capture")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Brand.black)

                SettingsGroupBox(title: "After Capture") {
                    SettingsToggleRow(
                        title: "Auto-copy to clipboard",
                        subtitle: "Automatically copy screenshots to the clipboard",
                        isOn: $settings.screenshotAutoCopy
                    )
                }

                SettingsGroupBox(title: "macOS Shortcuts") {
                    SettingsButtonRow(
                        title: "Using \u{2318}\u{21E7}3 and \u{2318}\u{21E7}4",
                        subtitle: "macOS keeps these for its own screenshots. Turn them off under Keyboard Shortcuts \u{203A} Screenshots, or pick different keys in Shortcuts.",
                        buttonTitle: "Open",
                        action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Privacy Settings Pane

struct PrivacySettingsPane: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Brand.black)

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
            .padding(28)
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
        VStack(alignment: .leading, spacing: 0) {
            Text("IGNORED APPLICATIONS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Brand.gray500)
                .tracking(1.5)
                .padding(.bottom, 4)

            Text("Content from these apps will not be saved.")
                .font(.system(size: 11))
                .foregroundStyle(Brand.gray500)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                appListContent

                Rectangle()
                    .fill(Brand.gray200)
                    .frame(height: 1)

                appListToolbar
            }
            .overlay(
                Rectangle()
                    .stroke(Brand.gray200, lineWidth: 1)
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
                            Rectangle()
                                .fill(Brand.gray200)
                                .frame(height: 1)
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
            VStack(spacing: 6) {
                Text("—")
                    .font(.system(size: 20, weight: .light, design: .monospaced))
                    .foregroundStyle(Brand.gray400)
                Text("No ignored applications")
                    .font(.system(size: 11))
                    .foregroundStyle(Brand.gray500)
            }
            .padding(.vertical, 28)
            Spacer()
        }
        .background(Brand.white)
    }

    private func appRow(_ app: IgnoredAppInfo) -> some View {
        HStack(spacing: 10) {
            appIcon(app)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Brand.black)
                Text(app.id)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Brand.gray500)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(selectedAppID == app.id ? Brand.gray200 : Brand.white)
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
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: "app")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Brand.gray400)
                .frame(width: 22, height: 22)
        }
    }

    private var appListToolbar: some View {
        HStack(spacing: 0) {
            Button {
                showingAppPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Brand.gray600)
                    .frame(width: 32, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add app to ignored list")

            Rectangle()
                .fill(Brand.gray200)
                .frame(width: 1, height: 16)

            Button {
                if let id = selectedAppID {
                    settings.removeIgnoredApp(id)
                    selectedAppID = nil
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selectedAppID != nil ? Brand.gray600 : Brand.gray300)
                    .frame(width: 32, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove app from ignored list")
            .disabled(selectedAppID == nil)

            Spacer()
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .background(Brand.gray100)
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
            Rectangle()
                .fill(Brand.gray200)
                .frame(height: 1)
            appList
        }
        .frame(width: 280, height: 320)
        .onAppear { loadInstalledApps() }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Brand.gray500)
            TextField("Search applications", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(10)
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
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Brand.gray400)
                        .frame(width: 18, height: 18)
                }

                Text(app.name)
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.black)
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
    @ObservedObject var snippetManager: SnippetManager

    @State private var showClearHistoryAlert = false
    @State private var showClearPinboardsAlert = false
    @State private var transferMessage: String?

    private let historySizeOptions = [0, 25, 50, 100, 200, 500]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Storage")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Brand.black)

                SettingsGroupBox(title: "History") {
                    HStack {
                        Text("Max history size")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Brand.black)

                        Spacer()

                        Picker("", selection: $settings.maxHistorySize) {
                            ForEach(historySizeOptions, id: \.self) { option in
                                Text(option == 0 ? "Unlimited" : "\(option)").tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Brand.white)
                    SettingsDivider()
                    SettingsInfoRow(title: "Items stored", value: "\(clipboardManager.history.count)")
                    SettingsDivider()
                    SettingsInfoRow(title: "Pinned items", value: "\(pinboardManager.totalPinnedItemCount)")
                }

                SettingsGroupBox(title: "Data") {
                    SettingsButtonRow(
                        title: "Clear clipboard history",
                        subtitle: "Remove everything except pinned items",
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
                        subtitle: "Save history, pinboards and snippets to a file",
                        buttonTitle: "Export",
                        action: { exportData() }
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Import data",
                        subtitle: "Add the contents of an exported file to what you have",
                        buttonTitle: "Import",
                        action: { importData() }
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Clear on quit",
                        subtitle: "Erase history when Superclip quits",
                        isOn: $settings.clearOnQuit
                    )
                }
            }
            .padding(28)
        }
        .alert("Clear History", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clipboardManager.clearHistory()
            }
        } message: {
            Text("This will remove your clipboard history. Items pinned to a pinboard are kept. This cannot be undone.")
        }
        .alert("Clear Pinboards", isPresented: $showClearPinboardsAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                pinboardManager.clearAllPinboards()
            }
        } message: {
            Text("This will remove all pinned items from every pinboard. This cannot be undone.")
        }
        .alert(
            "Superclip",
            isPresented: Binding(
                get: { transferMessage != nil },
                set: { if !$0 { transferMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(transferMessage ?? "")
        }
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        let stamp = Date().formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "Superclip Export \(stamp).json"
        panel.message = "The export contains your clipboard history in readable form. Keep it somewhere private."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try DataArchive.export(
                clipboard: clipboardManager, pinboards: pinboardManager, snippets: snippetManager)
            try data.write(to: url, options: .atomic)
            transferMessage = "Exported \(clipboardManager.history.count) clips, \(pinboardManager.pinboards.count) pinboards and \(snippetManager.snippets.count) snippets."
        } catch {
            transferMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a Superclip export. Its contents are added to what you already have."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let summary = try DataArchive.importArchive(
                data, clipboard: clipboardManager, pinboards: pinboardManager,
                snippets: snippetManager)
            transferMessage = summary.description
        } catch {
            transferMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - About Settings Pane

struct AboutSettingsPane: View {
    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // App icon
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 72, height: 72)
                } else {
                    Rectangle()
                        .fill(Brand.gray200)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(Brand.gray500)
                        )
                }

                VStack(spacing: 6) {
                    Text("SUPERCLIP")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Brand.black)

                    Text(appVersion)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Brand.gray500)
                }

                Text("Clipboard manager for macOS")
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.gray500)
            }

            Spacer()

            // Actions
            VStack(spacing: 0) {
                SettingsGroupBox(title: "") {
                    SettingsButtonRow(
                        title: "Check for updates",
                        buttonTitle: "Check",
                        action: {
                            NotificationCenter.default.post(name: .superclipCheckForUpdates, object: nil)
                        }
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Setup guide",
                        buttonTitle: "Show",
                        action: {
                            NotificationCenter.default.post(name: .superclipShowSetupGuide, object: nil)
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
            .padding(.horizontal, 28)
            .padding(.bottom, 16)

            // Quit buttons
            HStack(spacing: 8) {
                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .bold))
                        Text("QUIT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                    }
                    .foregroundStyle(Brand.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .overlay(
                        Rectangle()
                            .stroke(Brand.gray300, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showResetAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .bold))
                        Text("QUIT & RESET")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .overlay(
                        Rectangle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 28)
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
            snippetList
                .frame(width: 220)

            Rectangle()
                .fill(Brand.gray200)
                .frame(width: 1)

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
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Brand.black)

                Spacer()

                Text("\(snippetManager.enabledSnippetCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Brand.gray500)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        Rectangle()
                            .stroke(Brand.gray300, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle()
                .fill(Brand.gray200)
                .frame(height: 1)

            // List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(snippetManager.snippets) { snippet in
                        snippetRow(snippet)
                    }
                }
            }

            Rectangle()
                .fill(Brand.gray200)
                .frame(height: 1)

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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Brand.gray600)
                        .frame(width: 32, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add snippet")

                Rectangle()
                    .fill(Brand.gray200)
                    .frame(width: 1, height: 16)

                Button {
                    if let id = selectedSnippetId, let snippet = snippetManager.snippets.first(where: { $0.id == id }) {
                        snippetManager.deleteSnippet(snippet)
                        selectedSnippetId = nil
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selectedSnippetId != nil ? Brand.gray600 : Brand.gray300)
                        .frame(width: 32, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete snippet")
                .disabled(selectedSnippetId == nil)

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(Brand.gray100)
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
                Rectangle()
                    .fill(snippet.isEnabled ? Brand.black : Brand.gray300)
                    .frame(width: 3, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.name.isEmpty ? "Untitled" : snippet.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Brand.black)
                        .lineLimit(1)

                    Text(snippet.trigger)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Brand.gray500)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(selectedSnippetId == snippet.id ? Brand.gray200 : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Snippet Editor

    var snippetEditor: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(isCreating ? "New Snippet" : "Edit Snippet")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Brand.black)

                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("NAME")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Brand.gray500)
                        .tracking(1)

                    TextField("e.g., Email address", text: $editName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Brand.white)
                        .overlay(
                            Rectangle()
                                .stroke(Brand.gray300, lineWidth: 1)
                        )
                }

                // Trigger
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRIGGER")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Brand.gray500)
                        .tracking(1)

                    TextField("e.g., ;;email", text: $editTrigger)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(Brand.white)
                        .overlay(
                            Rectangle()
                                .stroke(Brand.gray300, lineWidth: 1)
                        )

                    Text("Type this anywhere to expand the snippet")
                        .font(.system(size: 10))
                        .foregroundStyle(Brand.gray500)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONTENT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Brand.gray500)
                        .tracking(1)

                    TextEditor(text: $editContent)
                        .font(.system(size: 12))
                        .frame(minHeight: 100, maxHeight: 200)
                        .padding(4)
                        .background(Brand.white)
                        .overlay(
                            Rectangle()
                                .stroke(Brand.gray300, lineWidth: 1)
                        )
                }

                if let error = editError {
                    Text(error)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                }

                // Actions
                HStack {
                    if !isCreating, let snippet = selectedSnippet {
                        Button {
                            snippetManager.toggleSnippet(snippet)
                        } label: {
                            Text(snippet.isEnabled ? "DISABLE" : "ENABLE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.5)
                                .foregroundStyle(Brand.gray600)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .overlay(
                                    Rectangle()
                                        .stroke(Brand.gray300, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        saveSnippet()
                    } label: {
                        Text(isCreating ? "CREATE" : "SAVE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(Brand.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 6)
                            .background(Brand.black)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
        }
    }

    var emptyState: some View {
        VStack(spacing: 10) {
            Text("—")
                .font(.system(size: 28, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(Brand.gray300)

            Text("Select or create a snippet")
                .font(.system(size: 12))
                .foregroundStyle(Brand.gray500)

            Text("Type a trigger anywhere to auto-expand")
                .font(.system(size: 11))
                .foregroundStyle(Brand.gray400)
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
        if let clash = snippetManager.conflictingTrigger(for: trimmedTrigger, excludingId: excludeId) {
            editError = "Clashes with the trigger \u{201C}\(clash)\u{201D}: one starts with the other, so the longer one could never fire"
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
