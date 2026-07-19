//
//  ImageEditorPanel.swift
//  Superclip
//

import AppKit
import SwiftUI

class ImageEditorPanel: NSPanel {
  weak var appDelegate: AppDelegate?
  var onSave: ((NSImage, Data) -> Void)?
  var onCancel: (() -> Void)?
  private var localKeyMonitor: Any?

  init(image: NSImage, pngData: Data, frame: NSRect) {
    super.init(
      contentRect: frame,
      styleMask: [.borderless, .resizable],
      backing: .buffered,
      defer: true
    )

    minSize = NSSize(width: 800, height: 600)
    setupWindow()
    setupContentView(image: image, pngData: pngData)
    setupKeyMonitor()
  }

  deinit {
    if let monitor = localKeyMonitor {
      NSEvent.removeMonitor(monitor)
    }
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  private func setupWindow() {
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    level = .normal
    hidesOnDeactivate = false
    isMovableByWindowBackground = false
    titlebarAppearsTransparent = true
    titleVisibility = .hidden

    collectionBehavior = [.managed]
  }

  private func setupContentView(image: NSImage, pngData: Data) {
    let editorView = ImageAnnotationEditorView(
      originalImage: image,
      pngData: pngData,
      onSave: { [weak self] savedImage, savedData in
        self?.onSave?(savedImage, savedData)
      },
      onDismiss: { [weak self] in
        self?.onCancel?()
        self?.closePanel()
      }
    )

    let hostingView = NSHostingView(rootView: editorView)
    self.contentView = hostingView
  }

  private func setupKeyMonitor() {
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self = self, self.isKeyWindow else { return event }

      // Escape key - deselect annotation first, then close
      if event.keyCode == 53 {
        NotificationCenter.default.post(name: .imageEditorEscape, object: self)
        return nil
      }

      // Cmd+Z - undo (handled by AnnotationState via SwiftUI, but post notification for safety)
      if event.modifierFlags.contains(.command) && event.keyCode == 6 {
        if event.modifierFlags.contains(.shift) {
          NotificationCenter.default.post(name: .imageEditorRedo, object: self)
        } else {
          NotificationCenter.default.post(name: .imageEditorUndo, object: self)
        }
        return nil
      }

      // Backspace/Delete - delete selected annotation
      if event.keyCode == 51 || event.keyCode == 117 {
        NotificationCenter.default.post(name: .imageEditorDeleteSelected, object: self)
        return nil
      }

      // Cmd+W - close editor window
      if event.modifierFlags.contains(.command) && event.keyCode == 13 {
        self.onCancel?()
        self.closePanel()
        return nil
      }

      // Cmd+Enter or Cmd+S - save/copy to clipboard
      if event.modifierFlags.contains(.command) {
        if event.keyCode == 36 || event.keyCode == 1 {
          NotificationCenter.default.post(name: .imageEditorSave, object: self)
          return nil
        }
      }

      // Number keys 1-0 → switch annotation tools (no modifiers held)
      let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
      if modifiers.isEmpty, let chars = event.charactersIgnoringModifiers {
        let keyToIndex: [Character: Int] = [
          "1": 0, "2": 1, "3": 2, "4": 3, "5": 4,
          "6": 5, "7": 6, "8": 7, "9": 8, "0": 9,
        ]
        if let ch = chars.first, let toolIndex = keyToIndex[ch] {
          NotificationCenter.default.post(
            name: .imageEditorSelectTool,
            object: self,
            userInfo: ["toolIndex": toolIndex]
          )
          return nil
        }
      }

      return event
    }
  }

  private func closePanel() {
    if let monitor = localKeyMonitor {
      NSEvent.removeMonitor(monitor)
      localKeyMonitor = nil
    }
    appDelegate?.removeImageEditorWindow(self)
    close()
  }
}

extension Notification.Name {
  static let imageEditorUndo = Notification.Name("imageEditorUndo")
  static let imageEditorRedo = Notification.Name("imageEditorRedo")
  static let imageEditorSave = Notification.Name("imageEditorSave")
  static let imageEditorEscape = Notification.Name("imageEditorEscape")
  static let imageEditorDeleteSelected = Notification.Name("imageEditorDeleteSelected")
  static let imageEditorSelectTool = Notification.Name("imageEditorSelectTool")
}
