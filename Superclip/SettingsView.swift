//
//  SettingsView.swift
//  Superclip
//

import SwiftUI

// MARK: - Settings Sections

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case shortcuts = "Shortcuts"
    case storage = "Storage"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .shortcuts: return "keyboard.fill"
        case .storage: return "internaldrive.fill"
        case .about: return "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: return .gray
        case .appearance: return .purple
        case .shortcuts: return .orange
        case .storage: return .blue
        case .about: return .green
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var onClose: () -> Void

    @State private var selectedSection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
                .frame(width: 200)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)

            // Detail pane
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 480)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
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
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close settings")

                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))

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
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Detail Pane

    @ViewBuilder
    var detailPane: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsPane()
        case .appearance:
            AppearanceSettingsPane()
        case .shortcuts:
            ShortcutsSettingsPane()
        case .storage:
            StorageSettingsPane()
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
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(section.iconColor)
                    )

                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.7))

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.15) : (isHovered ? Color.white.opacity(0.08) : Color.clear))
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
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 1) {
                content()
            }
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @State var isOn: Bool = false

    init(title: String, subtitle: String? = nil, isOn: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = State(initialValue: isOn)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
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
    @State var selection: T

    init(title: String, options: [T], selection: T) {
        self.title = title
        self.options = options
        self._selection = State(initialValue: selection)
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))

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
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            Button {
                action()
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
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
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Text(shortcut)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 12)
    }
}

// MARK: - General Settings Pane

struct GeneralSettingsPane: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Pane title
                Text("General")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                SettingsGroupBox(title: "Startup") {
                    SettingsToggleRow(
                        title: "Launch at login",
                        subtitle: "Start Superclip when you log in",
                        isOn: true
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Show in menu bar",
                        subtitle: "Display Superclip icon in the menu bar",
                        isOn: true
                    )
                }

                SettingsGroupBox(title: "Clipboard") {
                    SettingsToggleRow(
                        title: "Monitor clipboard",
                        subtitle: "Automatically capture clipboard changes",
                        isOn: true
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Deduplicate items",
                        subtitle: "Avoid saving duplicate clipboard entries",
                        isOn: true
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Detect links",
                        subtitle: "Fetch metadata for copied URLs",
                        isOn: true
                    )
                }

                SettingsGroupBox(title: "Behavior") {
                    SettingsToggleRow(
                        title: "Paste after selecting",
                        subtitle: "Automatically paste when selecting an item",
                        isOn: true
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Close after pasting",
                        subtitle: "Dismiss the window after pasting",
                        isOn: true
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Play sound effects",
                        isOn: false
                    )
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Appearance Settings Pane

struct AppearanceSettingsPane: View {
    @State private var selectedTheme = "System"
    private let themes = ["System", "Light", "Dark"]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Appearance")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                SettingsGroupBox(title: "Theme") {
                    HStack {
                        Text("Theme")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))

                        Spacer()

                        HStack(spacing: 0) {
                            ForEach(themes, id: \.self) { theme in
                                Button {
                                    selectedTheme = theme
                                } label: {
                                    Text(theme)
                                        .font(.system(size: 12, weight: selectedTheme == theme ? .medium : .regular))
                                        .foregroundStyle(.white.opacity(selectedTheme == theme ? 1.0 : 0.5))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(
                                            selectedTheme == theme ? Color.white.opacity(0.15) : Color.clear
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }

                SettingsGroupBox(title: "Window") {
                    SettingsToggleRow(
                        title: "Show item count",
                        subtitle: "Display number of items in the header",
                        isOn: true
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Show source app icons",
                        subtitle: "Display which app copied the item",
                        isOn: true
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Show timestamps",
                        subtitle: "Display when items were copied",
                        isOn: true
                    )
                }

                SettingsGroupBox(title: "Preview") {
                    SettingsToggleRow(
                        title: "Show link previews",
                        subtitle: "Fetch and display thumbnails for URLs",
                        isOn: true
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Syntax highlighting",
                        subtitle: "Highlight code snippets in preview",
                        isOn: true
                    )
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Shortcuts Settings Pane

struct ShortcutsSettingsPane: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Shortcuts")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                SettingsGroupBox(title: "Global Hotkeys") {
                    SettingsShortcutRow(title: "Open clipboard history", shortcut: "\u{2318}\u{21E7}A")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Open paste stack", shortcut: "\u{2318}\u{21E7}C")
                    SettingsDivider()
                    SettingsShortcutRow(title: "Screen capture OCR", shortcut: "\u{2318}\u{21E7}`")
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
    }
}

// MARK: - Storage Settings Pane

struct StorageSettingsPane: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Storage")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                SettingsGroupBox(title: "History") {
                    SettingsInfoRow(title: "History size", value: "100 items")
                    SettingsDivider()
                    SettingsInfoRow(title: "Items stored", value: "0 items")
                    SettingsDivider()
                    SettingsInfoRow(title: "Pinned items", value: "0 items")
                }

                SettingsGroupBox(title: "Data") {
                    SettingsButtonRow(
                        title: "Clear clipboard history",
                        subtitle: "Remove all items from history",
                        buttonTitle: "Clear",
                        action: {}
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Clear pinboards",
                        subtitle: "Remove all pinned items",
                        buttonTitle: "Clear",
                        action: {}
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Export data",
                        subtitle: "Export history and pins to a file",
                        buttonTitle: "Export",
                        action: {}
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Import data",
                        subtitle: "Restore from an exported file",
                        buttonTitle: "Import",
                        action: {}
                    )
                }

                SettingsGroupBox(title: "Privacy") {
                    SettingsToggleRow(
                        title: "Exclude sensitive apps",
                        subtitle: "Don't capture from password managers",
                        isOn: true
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Clear on quit",
                        subtitle: "Erase history when Superclip quits",
                        isOn: false
                    )
                }
            }
            .padding(24)
        }
    }
}

// MARK: - About Settings Pane

struct AboutSettingsPane: View {
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
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 80, height: 80)
                }

                // App name
                Text("Superclip")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                // Version
                Text("Version \(appVersion)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))

                // Description
                Text("A modern clipboard manager for macOS")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)
            }

            Spacer()

            // Footer links
            VStack(spacing: 12) {
                SettingsGroupBox(title: "") {
                    SettingsButtonRow(
                        title: "Check for updates",
                        buttonTitle: "Check",
                        action: {}
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Rate on App Store",
                        buttonTitle: "Rate",
                        action: {}
                    )
                    SettingsDivider()
                    SettingsButtonRow(
                        title: "Send feedback",
                        buttonTitle: "Email",
                        action: {}
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Quit button
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
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
