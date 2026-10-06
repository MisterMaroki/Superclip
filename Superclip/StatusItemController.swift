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
import Sparkle

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

    // Dim the icon while capture is paused, so "why isn't it saving my
    // copies?" has a visible answer in the menu bar.
    appDelegate.settingsManager.$monitorClipboard
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isMonitoring in
        self?.statusItem.button?.appearsDisabled = !isMonitoring
        self?.statusItem.button?.toolTip =
          isMonitoring ? "Superclip" : "Superclip (clipboard capture paused)"
      }
      .store(in: &cancellables)
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
        "Open Clipboard History", symbol: "clipboard", config: settings.hotkeyConfigForHistory(),
        action: #selector(openHistory)))
    menu.addItem(
      shortcutItem(
        "Open Paste Stack", symbol: "square.stack.3d.up",
        config: settings.hotkeyConfigForPasteStack(),
        action: #selector(openPasteStack)))
    menu.addItem(.separator())
    menu.addItem(
      shortcutItem(
        "Take Screenshot", symbol: "camera.viewfinder",
        config: settings.hotkeyConfigForScreenshot(),
        action: #selector(takeScreenshot)))
    menu.addItem(
      shortcutItem(
        "Capture Full Screen", symbol: "macwindow",
        config: settings.hotkeyConfigForFullscreenScreenshot(),
        action: #selector(captureFullScreen)))
    menu.addItem(
      shortcutItem(
        "Text Sniper (OCR)", symbol: "text.viewfinder", config: settings.hotkeyConfigForOCR(),
        action: #selector(captureText)))
    menu.addItem(.separator())

    // Checked while paused. Nothing copied during a pause is recorded, even
    // after capture is resumed.
    let pauseItem = plainItem(
      "Pause Clipboard Capture", symbol: "pause.circle", action: #selector(togglePause))
    pauseItem.state = settings.monitorClipboard ? .off : .on
    menu.addItem(pauseItem)
    menu.addItem(.separator())

    menu.addItem(
      plainItem("Settings\u{2026}", symbol: "gearshape", action: #selector(openSettings), key: ","))
    menu.addItem(
      plainItem("Setup Guide\u{2026}", symbol: "questionmark.circle", action: #selector(showSetupGuide)))
    menu.addItem(
      plainItem(
        "Check for Updates\u{2026}", symbol: "arrow.triangle.2.circlepath",
        action: #selector(checkForUpdates)))
    menu.addItem(.separator())

    menu.addItem(plainItem("Quit Superclip", symbol: "power", action: #selector(quit), key: "q"))
  }

  private func plainItem(_ title: String, symbol: String, action: Selector, key: String = "")
    -> NSMenuItem
  {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = self
    item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    return item
  }

  /// Menu item whose key equivalent mirrors a global hotkey. The global hotkey
  /// does the real work; the equivalent is shown purely so users can learn it.
  private func shortcutItem(_ title: String, symbol: String, config: HotkeyConfig, action: Selector)
    -> NSMenuItem
  {
    let item = plainItem(title, symbol: symbol, action: action)
    if let key = config.key {
      item.keyEquivalent = key.description.lowercased()
      item.keyEquivalentModifierMask = config.modifiers.intersection([.command, .shift, .option, .control])
    }
    return item
  }

  @objc private func openHistory() { appDelegate.showContentWindow() }
  @objc private func openPasteStack() { appDelegate.togglePasteStackWindow() }
  @objc private func takeScreenshot() { appDelegate.startScreenshotCapture() }
  @objc private func captureFullScreen() { appDelegate.captureFullscreenNow() }
  @objc private func captureText() { appDelegate.startScreenCapture() }
  @objc private func togglePause() { appDelegate.settingsManager.monitorClipboard.toggle() }
  @objc private func openSettings() { appDelegate.openSettingsWindow() }
  @objc private func showSetupGuide() { appDelegate.showOnboarding() }
  @objc private func checkForUpdates() { appDelegate.updaterController.checkForUpdates(nil) }
  @objc private func quit() { NSApp.terminate(nil) }
}
