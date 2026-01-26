//
//  AppDelegate.swift
//  Superclip
//

import AppKit
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    var contentWindow: NSWindow?
    var pasteStackWindow: NSWindow?
    var previewWindow: NSWindow?
    var richTextEditorWindows: [RichTextEditorPanel] = []
    var hotKey: HotKey?
    var pasteStackHotKey: HotKey?
    var clickMonitor: Any?
    var pasteStackKeyMonitor: Any?
    let clipboardManager = ClipboardManager()
    lazy var pasteStackManager = PasteStackManager(clipboardManager: clipboardManager)
    private var shouldPasteAfterClose = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupHotkey()
        setupPasteStackHotkey()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Close content panel when app loses focus (paste stack stays open)
        closeReviewWindow(andPaste: false)
    }
    
    private func setupHotkey() {
        hotKey = HotKey(key: .a, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleContentWindow()
            }
        }
    }
    
    private func setupPasteStackHotkey() {
        pasteStackHotKey = HotKey(key: .c, modifiers: [.command, .shift])
        pasteStackHotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.togglePasteStackWindow()
            }
        }
    }
    
    func toggleContentWindow() {
        // If panel is open, close it; otherwise open it
        if contentWindow != nil && contentWindow?.isVisible == true {
            closeReviewWindow(andPaste: false)
        } else {
            showContentWindow()
        }
    }
    
    func showContentWindow() {
        self.closeReviewWindow(andPaste: false)
        
        let contentPanel = ContentPanel(clipboardManager: clipboardManager)
        contentPanel.appDelegate = self
        
        contentWindow = contentPanel
        
        contentPanel.makeKeyAndOrderFront(nil)
        contentPanel.makeKey()
        
        // Start monitoring for clicks outside the panel and ESC key
        startClickMonitoring()
    }
    
    // MARK: - Paste Stack Window
    
    func togglePasteStackWindow() {
        if pasteStackWindow != nil && pasteStackWindow?.isVisible == true {
            closePasteStackWindow(andPaste: false)
        } else {
            showPasteStackWindow()
        }
    }
    
    func showPasteStackWindow() {
        self.closeReviewWindow(andPaste: false)
        
        // If already open, just bring to front
        if pasteStackWindow != nil && pasteStackWindow?.isVisible == true {
            pasteStackWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        // Start a new paste stack session
        pasteStackManager.startSession()
        
        let pasteStackPanel = PasteStackPanel(pasteStackManager: pasteStackManager)
        pasteStackPanel.appDelegate = self
        
        pasteStackWindow = pasteStackPanel
        
        pasteStackPanel.orderFront(nil)
        
        // Start monitoring for paste events (Cmd+V)
        startPasteStackKeyMonitoring()
    }
    
    /// Handle paste from paste stack without closing the window
    func handlePasteStackPaste(shouldPaste: Bool) {
        if shouldPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.simulatePaste()
            }
        }
    }
    
    func closePasteStackWindow(andPaste shouldPaste: Bool) {
        // Stop monitoring for paste events
        stopPasteStackKeyMonitoring()
        
        if let window = pasteStackWindow {
            window.close()
            pasteStackWindow = nil
        }
        
        // End the session when closing
        pasteStackManager.endSession()
        
        if shouldPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.simulatePaste()
            }
        }
    }
    
    private func startPasteStackKeyMonitoring() {
        stopPasteStackKeyMonitoring() // Clean up any existing monitor first
        
        // Use global monitor to detect Cmd+V in other apps
        pasteStackKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  self.pasteStackWindow?.isVisible == true else { return }
            
            // Check for Cmd+V (key code 9 is 'V', Command modifier)
            if event.keyCode == 9 && event.modifierFlags.contains(.command) {
                DispatchQueue.main.async {
                    // Small delay to let the paste complete before advancing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.pasteStackManager.advanceAfterPaste()
                    }
                }
            }
        }
    }
    
    private func stopPasteStackKeyMonitoring() {
        if let monitor = pasteStackKeyMonitor {
            NSEvent.removeMonitor(monitor)
            pasteStackKeyMonitor = nil
        }
    }
    
    private func startClickMonitoring() {
        stopClickMonitoring() // Clean up any existing monitor first
        
        guard let panelWindow = contentWindow else { return }
        
        // Monitor mouse down events, key events, and modifier changes
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown, .keyUp, .flagsChanged]) { [weak self] event -> NSEvent? in
            guard let self = self,
                  let panelWindow = self.contentWindow as? ContentPanel else {
                return event
            }
            
            // Track Command key state for quick digit selection
            if event.type == .flagsChanged {
                let isCommandPressed = event.modifierFlags.contains(.command)
                panelWindow.navigationState.isCommandHeld = isCommandPressed
                return event
            }

            if event.type == .keyDown {
                // Quick digit selection when Command is held (1-9, 0)
                // Key codes: 1=18, 2=19, 3=20, 4=21, 5=23, 6=22, 7=26, 8=28, 9=25, 0=29
                if event.modifierFlags.contains(.command) {
                    let digitKeyCodes: [UInt16: Int] = [
                        18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
                        22: 6, 26: 7, 28: 8, 25: 9, 29: 0
                    ]
                    if let digit = digitKeyCodes[event.keyCode] {
                        panelWindow.navigationState.selectByDigit(digit)
                        return nil
                    }
                }

                switch event.keyCode {
                case 53: // ESC key
                    DispatchQueue.main.async {
                        // If editing, cancel editing first (don't close preview)
                        if let previewPanel = self.previewWindow as? PreviewPanel,
                           previewPanel.editingState.isEditing {
                            previewPanel.editingState.cancelEditing()
                            return
                        }
                        // Close preview first if open, otherwise close drawer
                        if self.previewWindow?.isVisible == true {
                            self.closePreviewWindow()
                            self.contentWindow?.makeKey()
                        } else {
                            self.closeReviewWindow(andPaste: false)
                        }
                    }
                    return nil
                case 123: // Left arrow
                    panelWindow.navigationState.moveLeft()
                    return nil
                case 124: // Right arrow
                    panelWindow.navigationState.moveRight()
                    return nil
                case 125: // Down arrow
                    panelWindow.navigationState.moveRight()
                    return nil
                case 126: // Up arrow
                    panelWindow.navigationState.moveLeft()
                    return nil
                case 36: // Return/Enter
                    panelWindow.navigationState.selectCurrent()
                    return nil
                case 44: // '/' key - focus search
                    panelWindow.navigationState.focusSearch()
                    return nil
                case 51: // Backspace key - delete selected item
                    // Don't delete if user is editing text
                    if let previewPanel = self.previewWindow as? PreviewPanel,
                       previewPanel.editingState.isEditing {
                        return event // Allow backspace to delete characters in editor
                    }
                    DispatchQueue.main.async {
                        panelWindow.navigationState.deleteCurrentItem()
                    }
                    return nil
                case 6: // 'Z' key
                    // Check for Cmd+Z (undo)
                    if event.modifierFlags.contains(.command) {
                        DispatchQueue.main.async {
                            self.clipboardManager.undoDelete()
                        }
                        return nil
                    }
                    return event
                case 49: // Space key - toggle preview or open editor on hold
                    // Don't handle if user is editing text
                    if let previewPanel = self.previewWindow as? PreviewPanel,
                       previewPanel.editingState.isEditing {
                        return event // Allow space to be typed in the text editor
                    }

                    // If key is being held (repeat), open the rich text editor directly
                    if event.isARepeat {
                        // Close preview if open, then open editor
                        self.closePreviewWindow()
                        self.openRichTextEditorForSelectedItem()
                        return nil
                    }

                    // Normal press - toggle preview
                    if self.previewWindow?.isVisible == true {
                        self.closePreviewWindow()
                        self.contentWindow?.makeKey()
                    } else {
                        panelWindow.navigationState.showPreview()
                    }
                    return nil
                default:
                    return event
                }
            }
            
            // If click is in a different window (or nil), close the drawer panel
            // But don't close if clicking on the preview window, paste stack window, or rich text editor windows
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                let isRichTextEditorWindow = self.richTextEditorWindows.contains { $0 === event.window }
                if event.window != panelWindow &&
                   event.window != self.previewWindow &&
                   event.window != self.pasteStackWindow &&
                   !isRichTextEditorWindow {
                    DispatchQueue.main.async {
                        self.closeReviewWindow(andPaste: false)
                    }
                    return event
                }
            }
            
            return event
        }
        
        // Monitor for when the panel window loses key status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panelWindow
        )
    }
    
    @objc private func windowDidResignKey(_ notification: Notification) {
        // Don't close if the preview window, paste stack window, or rich text editor windows are becoming key
        if notification.object as? NSWindow == contentWindow {
            if let preview = previewWindow, preview.isVisible {
                return
            }
            if let pasteStack = pasteStackWindow, pasteStack.isVisible {
                return
            }
            // Check if any rich text editor window is visible
            if richTextEditorWindows.contains(where: { $0.isVisible }) {
                return
            }
            closeReviewWindow(andPaste: false)
        }
    }
    
    private func stopClickMonitoring() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: contentWindow)
    }
    
    func closeReviewWindow(andPaste shouldPaste: Bool) {
        stopClickMonitoring()
        
        // Close preview window if open
        closePreviewWindow()
        
        if let window = contentWindow {
            window.close()
            contentWindow = nil
        }
        
        // If we should paste, do it after a brief delay to let the previous app regain focus
        if shouldPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.simulatePaste()
            }
        }
    }
    
    private func simulatePaste() {
        // Create and post Cmd+V key event
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key code 9 is 'V'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        
        // Add Command modifier
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        // Post the events
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    func simulatePastePublic() {
        simulatePaste()
    }
    
    // MARK: - Preview Window
    
    func showPreviewWindow(for item: ClipboardItem, atIndex index: Int) {
        closePreviewWindow()
        
        let previewPanel = PreviewPanel(item: item, clipboardManager: clipboardManager)
        previewPanel.appDelegate = self
        previewPanel.onDismiss = { [weak self] in
            self?.closePreviewWindow()
            // Return focus to content window
            self?.contentWindow?.makeKey()
        }
        
        previewWindow = previewPanel
        
        // Position preview above the selected card in the drawer
        if let contentWindow = contentWindow {
            let drawerFrame = contentWindow.frame
            
            // Use larger size for image editor
            let panelWidth: CGFloat = item.type == .image ? 600 : 500
            let panelHeight: CGFloat = item.type == .image ? 500 : 400
            
            // Card dimensions (from ContentView)
            let cardWidth: CGFloat = 220
            let cardSpacing: CGFloat = 14
            let horizontalPadding: CGFloat = 20
            
            // Calculate card center x position
            let cardStartX = drawerFrame.minX + horizontalPadding
            let cardCenterX = cardStartX + (CGFloat(index) * (cardWidth + cardSpacing)) + (cardWidth / 2)
            
            // Center preview horizontally above the card
            var previewX = cardCenterX - (panelWidth / 2)
            
            // Make sure preview stays on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                previewX = max(screenFrame.minX + 16, min(previewX, screenFrame.maxX - panelWidth - 16))
            }
            
            // Position preview above the drawer with a small gap
            let previewY = drawerFrame.maxY + 12
            
            previewPanel.setFrame(
                NSRect(x: previewX, y: previewY, width: panelWidth, height: panelHeight),
                display: true
            )
        }
        
        previewPanel.orderFront(nil)
    }
    
    func closePreviewWindow() {
        if let window = previewWindow {
            window.close()
            previewWindow = nil
        }
    }

    // MARK: - Rich Text Editor Window

    /// Open rich text editor for the currently selected item (called when holding spacebar)
    func openRichTextEditorForSelectedItem() {
        guard let contentPanel = contentWindow as? ContentPanel else { return }
        let index = contentPanel.navigationState.selectedIndex
        let filteredHistory = clipboardManager.history // In real use, this should match ContentView's filtered list
        guard index >= 0, index < filteredHistory.count else { return }
        let item = filteredHistory[index]

        // Only open editor for text items
        guard item.type == .text || item.type == .url else { return }

        // Calculate frame position (same logic as showPreviewWindow)
        let editorFrame: NSRect
        if let contentWindow = contentWindow {
            let drawerFrame = contentWindow.frame
            let panelWidth: CGFloat = 500
            let panelHeight: CGFloat = 400

            let cardWidth: CGFloat = 220
            let cardSpacing: CGFloat = 14
            let horizontalPadding: CGFloat = 20

            let cardStartX = drawerFrame.minX + horizontalPadding
            let cardCenterX = cardStartX + (CGFloat(index) * (cardWidth + cardSpacing)) + (cardWidth / 2)

            var editorX = cardCenterX - (panelWidth / 2)

            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                editorX = max(screenFrame.minX + 16, min(editorX, screenFrame.maxX - panelWidth - 16))
            }

            let editorY = drawerFrame.maxY + 12
            editorFrame = NSRect(x: editorX, y: editorY, width: panelWidth, height: panelHeight)
        } else {
            editorFrame = NSRect(x: 100, y: 100, width: 500, height: 400)
        }

        showRichTextEditorWindow(for: item, fromPreviewFrame: editorFrame)
    }

    func showRichTextEditorWindow(for item: ClipboardItem, fromPreviewFrame previewFrame: NSRect) {
        // Close drawer and preview
        closePreviewWindow()
        closeReviewWindow(andPaste: false)

        let editorPanel = RichTextEditorPanel(
            item: item,
            clipboardManager: clipboardManager,
            frame: previewFrame
        )
        editorPanel.appDelegate = self

        editorPanel.onSave = { [weak self] attributedString in
            guard let self = self else { return }
            // Update the item with rich content
            self.clipboardManager.updateItemRichContent(item, attributedString: attributedString)
            // Copy the updated item to clipboard so it's ready to paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let updatedItem = self.clipboardManager.history.first(where: { $0.id == item.id }) {
                    self.clipboardManager.copyToClipboard(updatedItem)
                }
            }
        }

        editorPanel.onCancel = {
            // Nothing special needed on cancel
        }

        richTextEditorWindows.append(editorPanel)
        editorPanel.makeKeyAndOrderFront(nil)
    }

    func removeRichTextEditorWindow(_ panel: RichTextEditorPanel) {
        richTextEditorWindows.removeAll { $0 === panel }
    }
}
