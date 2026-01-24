//
//  AppDelegate.swift
//  Superclip
//

import AppKit
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    var contentWindow: NSWindow?
    var hotKey: HotKey?
    var clickMonitor: Any?
    let clipboardManager = ClipboardManager()
    private var shouldPasteAfterClose = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupHotkey()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Close panel when app loses focus
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
                        self.closeReviewWindow(andPaste: false)
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
                default:
                    return event
                }
            }
            
            // If click is in a different window (or nil), close the panel
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if event.window != panelWindow {
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
        if notification.object as? NSWindow == contentWindow {
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
}