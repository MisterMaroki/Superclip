//
//  SettingsManager.swift
//  Superclip
//

import AppKit
import Combine
import ServiceManagement

class SettingsManager: ObservableObject {

    // MARK: - Startup

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    // MARK: - Sync

    /// Sync clips, pinboards and snippets through the user's iCloud. Off until
    /// the user turns it on: a clipboard history is private by default.
    @Published var syncEnabled: Bool {
        didSet { defaults.set(syncEnabled, forKey: Keys.syncEnabled) }
    }

    // MARK: - Clipboard

    @Published var monitorClipboard: Bool {
        didSet { defaults.set(monitorClipboard, forKey: Keys.monitorClipboard) }
    }

    @Published var deduplicateItems: Bool {
        didSet { defaults.set(deduplicateItems, forKey: Keys.deduplicateItems) }
    }

    @Published var detectLinks: Bool {
        didSet { defaults.set(detectLinks, forKey: Keys.detectLinks) }
    }

    // MARK: - Behavior

    @Published var pasteAfterSelecting: Bool {
        didSet { defaults.set(pasteAfterSelecting, forKey: Keys.pasteAfterSelecting) }
    }

    @Published var playSoundEffects: Bool {
        didSet { defaults.set(playSoundEffects, forKey: Keys.playSoundEffects) }
    }

    // MARK: - Appearance

    @Published var theme: String {
        didSet {
            defaults.set(theme, forKey: Keys.theme)
            applyTheme()
        }
    }

    @Published var showSourceAppIcons: Bool {
        didSet { defaults.set(showSourceAppIcons, forKey: Keys.showSourceAppIcons) }
    }

    @Published var showTimestamps: Bool {
        didSet { defaults.set(showTimestamps, forKey: Keys.showTimestamps) }
    }

    /// The strip of key hints along the bottom of the drawer.
    @Published var showKeyboardHints: Bool {
        didSet { defaults.set(showKeyboardHints, forKey: Keys.showKeyboardHints) }
    }

    @Published var showLinkPreviews: Bool {
        didSet { defaults.set(showLinkPreviews, forKey: Keys.showLinkPreviews) }
    }

    @Published var showItemCount: Bool {
        didSet { defaults.set(showItemCount, forKey: Keys.showItemCount) }
    }

    @Published var syntaxHighlighting: Bool {
        didSet { defaults.set(syntaxHighlighting, forKey: Keys.syntaxHighlighting) }
    }

    // MARK: - Privacy

    @Published var ignoreConfidentialContent: Bool {
        didSet { defaults.set(ignoreConfidentialContent, forKey: Keys.ignoreConfidentialContent) }
    }

    @Published var ignoreTransientContent: Bool {
        didSet { defaults.set(ignoreTransientContent, forKey: Keys.ignoreTransientContent) }
    }

    @Published var ignoredAppBundleIDs: [String] {
        didSet { defaults.set(ignoredAppBundleIDs, forKey: Keys.ignoredAppBundleIDs) }
    }

    // MARK: - Hotkeys

    @Published var historyHotkey: [String: Int] {
        didSet { defaults.set(historyHotkey, forKey: Keys.historyHotkey) }
    }

    @Published var pasteStackHotkey: [String: Int] {
        didSet { defaults.set(pasteStackHotkey, forKey: Keys.pasteStackHotkey) }
    }

    @Published var ocrHotkey: [String: Int] {
        didSet { defaults.set(ocrHotkey, forKey: Keys.ocrHotkey) }
    }

    @Published var screenshotHotkey: [String: Int] {
        didSet { defaults.set(screenshotHotkey, forKey: Keys.screenshotHotkey) }
    }

    @Published var fullscreenScreenshotHotkey: [String: Int] {
        didSet { defaults.set(fullscreenScreenshotHotkey, forKey: Keys.fullscreenScreenshotHotkey) }
    }

    // MARK: - Screen Capture

    @Published var screenshotAutoCopy: Bool {
        didSet { defaults.set(screenshotAutoCopy, forKey: Keys.screenshotAutoCopy) }
    }

    // MARK: - Drawer

    @Published var drawerHeight: CGFloat {
        didSet { defaults.set(Double(drawerHeight), forKey: Keys.drawerHeight) }
    }

    // MARK: - Storage

    @Published var maxHistorySize: Int {
        didSet { defaults.set(maxHistorySize, forKey: Keys.maxHistorySize) }
    }

    @Published var clearOnQuit: Bool {
        didSet { defaults.set(clearOnQuit, forKey: Keys.clearOnQuit) }
    }

    // MARK: - Private

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let launchAtLogin = "Superclip.launchAtLogin"
        static let monitorClipboard = "Superclip.monitorClipboard"
        static let syncEnabled = "Superclip.syncEnabled"
        static let deduplicateItems = "Superclip.deduplicateItems"
        static let detectLinks = "Superclip.detectLinks"
        static let pasteAfterSelecting = "Superclip.pasteAfterSelecting"
        static let playSoundEffects = "Superclip.playSoundEffects"
        static let theme = "Superclip.theme"
        static let showSourceAppIcons = "Superclip.showSourceAppIcons"
        static let showTimestamps = "Superclip.showTimestamps"
        static let showKeyboardHints = "Superclip.showKeyboardHints"
        static let showLinkPreviews = "Superclip.showLinkPreviews"
        static let showItemCount = "Superclip.showItemCount"
        static let syntaxHighlighting = "Superclip.syntaxHighlighting"
        static let ignoreConfidentialContent = "Superclip.ignoreConfidentialContent"
        static let ignoreTransientContent = "Superclip.ignoreTransientContent"
        static let ignoredAppBundleIDs = "Superclip.ignoredAppBundleIDs"
        static let historyHotkey = "Superclip.historyHotkey"
        static let pasteStackHotkey = "Superclip.pasteStackHotkey"
        static let ocrHotkey = "Superclip.ocrHotkey"
        static let screenshotHotkey = "Superclip.screenshotHotkey"
        static let fullscreenScreenshotHotkey = "Superclip.fullscreenScreenshotHotkey"
        static let screenshotAutoCopy = "Superclip.screenshotAutoCopy"
        static let drawerHeight = "Superclip.drawerHeight"
        static let maxHistorySize = "Superclip.maxHistorySize"
        static let clearOnQuit = "Superclip.clearOnQuit"
    }

    // MARK: - Init

    init() {
        let d = UserDefaults.standard

        // Register defaults for first launch
        d.register(defaults: [
            Keys.launchAtLogin: true,
            Keys.monitorClipboard: true,
            Keys.deduplicateItems: true,
            Keys.detectLinks: true,
            Keys.pasteAfterSelecting: true,
            Keys.playSoundEffects: false,
            Keys.theme: "System",
            Keys.showSourceAppIcons: true,
            Keys.showTimestamps: true,
            Keys.showLinkPreviews: true,
            Keys.showItemCount: true,
            Keys.syntaxHighlighting: true,
            Keys.ignoreConfidentialContent: true,
            Keys.ignoreTransientContent: true,
            Keys.ignoredAppBundleIDs: ["com.apple.keychainaccess", "com.apple.Passwords"],
            Keys.showKeyboardHints: true,
            // 28pt taller than before: room for the key-hint strip without shrinking the cards
            Keys.drawerHeight: Double(308),
            Keys.maxHistorySize: 0,
            Keys.clearOnQuit: false,
            Keys.historyHotkey: HotkeyConfig.defaultHistory.dictionary,
            Keys.pasteStackHotkey: HotkeyConfig.defaultPasteStack.dictionary,
            Keys.ocrHotkey: HotkeyConfig.defaultOCR.dictionary,
            Keys.screenshotHotkey: HotkeyConfig.defaultScreenshot.dictionary,
            Keys.fullscreenScreenshotHotkey: HotkeyConfig.defaultFullscreenScreenshot.dictionary,
            Keys.screenshotAutoCopy: true,
        ])

        // Reflect what the system actually has registered: the stored flag
        // alone can claim "on" when nothing was ever registered.
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.monitorClipboard = d.bool(forKey: Keys.monitorClipboard)
        self.syncEnabled = d.bool(forKey: Keys.syncEnabled)
        self.deduplicateItems = d.bool(forKey: Keys.deduplicateItems)
        self.detectLinks = d.bool(forKey: Keys.detectLinks)
        self.pasteAfterSelecting = d.bool(forKey: Keys.pasteAfterSelecting)
        self.playSoundEffects = d.bool(forKey: Keys.playSoundEffects)
        self.theme = d.string(forKey: Keys.theme) ?? "System"
        self.showSourceAppIcons = d.bool(forKey: Keys.showSourceAppIcons)
        self.showTimestamps = d.bool(forKey: Keys.showTimestamps)
        self.showKeyboardHints = d.bool(forKey: Keys.showKeyboardHints)
        self.showLinkPreviews = d.bool(forKey: Keys.showLinkPreviews)
        self.showItemCount = d.bool(forKey: Keys.showItemCount)
        self.syntaxHighlighting = d.bool(forKey: Keys.syntaxHighlighting)
        self.ignoreConfidentialContent = d.bool(forKey: Keys.ignoreConfidentialContent)
        self.ignoreTransientContent = d.bool(forKey: Keys.ignoreTransientContent)
        self.historyHotkey = (d.dictionary(forKey: Keys.historyHotkey) as? [String: Int]) ?? HotkeyConfig.defaultHistory.dictionary
        self.pasteStackHotkey = (d.dictionary(forKey: Keys.pasteStackHotkey) as? [String: Int]) ?? HotkeyConfig.defaultPasteStack.dictionary
        self.ocrHotkey = (d.dictionary(forKey: Keys.ocrHotkey) as? [String: Int]) ?? HotkeyConfig.defaultOCR.dictionary
        self.screenshotHotkey = (d.dictionary(forKey: Keys.screenshotHotkey) as? [String: Int]) ?? HotkeyConfig.defaultScreenshot.dictionary
        self.fullscreenScreenshotHotkey = (d.dictionary(forKey: Keys.fullscreenScreenshotHotkey) as? [String: Int]) ?? HotkeyConfig.defaultFullscreenScreenshot.dictionary
        self.screenshotAutoCopy = d.bool(forKey: Keys.screenshotAutoCopy)
        self.drawerHeight = CGFloat(d.double(forKey: Keys.drawerHeight))
        self.ignoredAppBundleIDs = d.stringArray(forKey: Keys.ignoredAppBundleIDs) ?? []
        self.maxHistorySize = d.integer(forKey: Keys.maxHistorySize)
        self.clearOnQuit = d.bool(forKey: Keys.clearOnQuit)
    }

    // MARK: - Theme

    func applyTheme() {
        switch theme {
        case "Light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "Dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }

    // MARK: - Launch at Login

    func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Registration may fail if entitlement is missing; silently ignore
            }
        }
    }

    // MARK: - Sound Effects

    func playSound() {
        guard playSoundEffects else { return }
        NSSound(named: "Tink")?.play()
    }

    // MARK: - Ignored Apps

    func isAppIgnored(bundleIdentifier: String?) -> Bool {
        guard let id = bundleIdentifier else { return false }
        return ignoredAppBundleIDs.contains(id)
    }

    func addIgnoredApp(_ bundleID: String) {
        if !ignoredAppBundleIDs.contains(bundleID) {
            ignoredAppBundleIDs.append(bundleID)
        }
    }

    func removeIgnoredApp(_ bundleID: String) {
        ignoredAppBundleIDs.removeAll { $0 == bundleID }
    }

    // MARK: - Hotkey Helpers

    func hotkeyConfigForHistory() -> HotkeyConfig {
        HotkeyConfig(dictionary: historyHotkey) ?? .defaultHistory
    }

    func hotkeyConfigForPasteStack() -> HotkeyConfig {
        HotkeyConfig(dictionary: pasteStackHotkey) ?? .defaultPasteStack
    }

    func hotkeyConfigForOCR() -> HotkeyConfig {
        HotkeyConfig(dictionary: ocrHotkey) ?? .defaultOCR
    }

    func hotkeyConfigForScreenshot() -> HotkeyConfig {
        HotkeyConfig(dictionary: screenshotHotkey) ?? .defaultScreenshot
    }

    func hotkeyConfigForFullscreenScreenshot() -> HotkeyConfig {
        HotkeyConfig(dictionary: fullscreenScreenshotHotkey) ?? .defaultFullscreenScreenshot
    }

    func resetHotkeysToDefaults() {
        historyHotkey = HotkeyConfig.defaultHistory.dictionary
        pasteStackHotkey = HotkeyConfig.defaultPasteStack.dictionary
        ocrHotkey = HotkeyConfig.defaultOCR.dictionary
        screenshotHotkey = HotkeyConfig.defaultScreenshot.dictionary
        fullscreenScreenshotHotkey = HotkeyConfig.defaultFullscreenScreenshot.dictionary
    }

    // MARK: - Reset

    /// Set by "Quit & Reset" so termination erases stored history instead of saving it.
    static var isResettingAllData = false

    /// Removes all Superclip keys from UserDefaults (settings, onboarding flag, pinboards, etc.)
    static func resetAllUserDefaults() {
        isResettingAllData = true
        guard let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }

}
