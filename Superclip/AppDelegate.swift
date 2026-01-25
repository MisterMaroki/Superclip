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
        
        // Monitor mouse down events and key events
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event -> NSEvent? in
            guard let self = self,
                  let panelWindow = self.contentWindow as? ContentPanel else {
                return event
            }
            
            if event.type == .keyDown {
                switch event.keyCode {
                case 53: // ESC key
                    DispatchQueue.main.async {
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
                case 49: // Space key - toggle preview
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
            // But don't close if clicking on the preview window or paste stack window
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if event.window != panelWindow && 
                   event.window != self.previewWindow && 
                   event.window != self.pasteStackWindow {
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
        // Don't close if the preview window or paste stack window is becoming key
        if notification.object as? NSWindow == contentWindow {
            if let preview = previewWindow, preview.isVisible {
                return
            }
            if let pasteStack = pasteStackWindow, pasteStack.isVisible {
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
}