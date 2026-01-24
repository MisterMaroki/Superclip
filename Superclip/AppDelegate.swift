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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupHotkey()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Close panel when app loses focus
        closeReviewWindow()
    }
    
    private func setupHotkey() {
        hotKey = HotKey(key: .a, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.showContentWindow()
            }
        }
    }
    
    func showContentWindow() {
        self.closeReviewWindow()
        
        let contentPanel = ContentPanel()
        contentPanel.appDelegate = self
        
        contentWindow = contentPanel
        
        contentPanel.makeKeyAndOrderFront(nil)
        contentPanel.makeKey()
        
        // Start monitoring for clicks outside the panel
        startClickMonitoring()
    }
    
    private func startClickMonitoring() {
        stopClickMonitoring() // Clean up any existing monitor first
        
        guard let panelWindow = contentWindow else { return }
        
        // Monitor mouse down events - this catches events within our app
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event -> NSEvent? in
            guard let self = self,
                  let panelWindow = self.contentWindow else {
                return event
            }
            
            // If click is in a different window (or nil), close the panel
            if event.window != panelWindow {
                DispatchQueue.main.async {
                    self.closeReviewWindow()
                }
                return event
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
            closeReviewWindow()
        }
    }
    
    private func stopClickMonitoring() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: contentWindow)
    }
    
    private func closeReviewWindow() {
        stopClickMonitoring()
        
        if let window = contentWindow {
            window.close()
            contentWindow = nil
        }
    }
}