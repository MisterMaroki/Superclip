//
//  StatusItemController.swift
//  Superclip
//
//  Menu bar icon. Superclip is an accessory app with no Dock icon, so this is
//  the only persistent, discoverable entry point once onboarding closes.
//

import AppKit
import Combine
import HotKey

final class StatusItemController: NSObject, NSMenuDelegate {
  private let statusItem: NSStatusItem
  private let menu = NSMenu()
  private unowned let appDelegate: AppDelegate
  private var cancellables = Set<AnyCancellable>()

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    super.init()

    if let button = statusItem.button {
      let image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Superclip")
      image?.isTemplate = true
      button.image = image
      button.toolTip = "Superclip"
    }

    menu.delegate = self
    statusItem.menu = menu
  }

  deinit {
    NSStatusBar.system.removeStatusItem(statusItem)
  }

  // Rebuild on every open so shortcut labels always reflect current settings.
  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    let settings = appDelegate.settingsManager

    menu.addItem(
      shortcutItem(
        "Open Clipboard History", config: settings.hotkeyConfigForHistory(),
        action: #selector(openHistory)))
    menu.addItem(
      shortcutItem(
        "Open Paste Stack", config: settings.hotkeyConfigForPasteStack(),
        action: #selector(openPasteStack)))
    menu.addItem(.separator())
    menu.addItem(
      shortcutItem(
        "Take Screenshot", config: settings.hotkeyConfigForScreenshot(),
        action: #selector(takeScreenshot)))
    menu.addItem(
      shortcutItem(
        "Capture Text (OCR)", config: settings.hotkeyConfigForOCR(),
        action: #selector(captureText)))
    menu.addItem(.separator())

    let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    settingsItem.target = self
    menu.addItem(settingsItem)
    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit Superclip", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)
  }

  /// Menu item whose key equivalent mirrors a global hotkey. The global hotkey
  /// does the real work; the equivalent is shown purely so users can learn it.
  private func shortcutItem(_ title: String, config: HotkeyConfig, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    if let key = config.key {
      item.keyEquivalent = key.description.lowercased()
      item.keyEquivalentModifierMask = config.modifiers.intersection([.command, .shift, .option, .control])
    }
    return item
  }

  @objc private func openHistory() { appDelegate.showContentWindow() }
  @objc private func openPasteStack() { appDelegate.togglePasteStackWindow() }
  @objc private func takeScreenshot() { appDelegate.startScreenshotCapture() }
  @objc private func captureText() { appDelegate.startScreenCapture() }
  @objc private func openSettings() { appDelegate.openSettingsWindow() }
  @objc private func quit() { NSApp.terminate(nil) }
}
