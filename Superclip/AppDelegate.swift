//
//  AppDelegate.swift
//  Superclip
//

import AppKit
import QuartzCore
import HotKey
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var contentWindow: NSWindow?
    var pasteStackWindow: NSWindow?
    var previewWindow: NSWindow?
    var richTextEditorWindows: [RichTextEditorPanel] = []
    var hotKey: HotKey?
    var pasteStackHotKey: HotKey?
    var ocrHotKey: HotKey?
    var screenCaptureWindow: NSWindow?
    var clickMonitor: Any?
    var pasteStackKeyMonitor: Any?
    var previewClickMonitor: Any?
    let clipboardManager = ClipboardManager()
    lazy var pasteStackManager = PasteStackManager(clipboardManager: clipboardManager)
    private var shouldPasteAfterClose = false
    
    // Hold-to-edit: timer-based progress, rebound on early release
    private var holdProgressTimer: Timer?
    private var holdCompletionTimer: Timer?
    private var holdStartTime: CFTimeInterval = 0
    private var holdCompleted = false
    private let holdDuration: TimeInterval = 0.5
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupHotkey()
        setupPasteStackHotkey()
        setupOCRHotkey()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Don't close if rich text editor windows are open
        if richTextEditorWindows.contains(where: { $0.isVisible }) {
            return
        }
        // Close both preview and drawer when app loses focus (paste stack stays open)
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
                    // Don't intercept if editing a pinboard - let the TextField handle it
                    if panelWindow.isEditingPinboard {
                        return event
                    }
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
                case 49: // Space key - toggle preview or hold-to-edit (timer-based, rebounding progress)
                    // Don't handle if user is editing text
                    if let previewPanel = self.previewWindow as? PreviewPanel,
                       previewPanel.editingState.isEditing {
                        return event // Allow space to be typed in the text editor
                    }

                    // Ignore key repeat; we use a timer for hold-to-edit
                    if event.isARepeat { return nil }

                    // Only hold-to-edit for editable (text/url) items
                    let history = self.clipboardManager.history
                    let idx = panelWindow.navigationState.selectedIndex
                    let isEditable = idx >= 0 && idx < history.count && (history[idx].type == .text || history[idx].type == .url)

                    if isEditable {
                        // Start hold: progress animation + completion timer
                        self.cancelHoldToEdit()
                        panelWindow.navigationState.isHoldingSpace = true
                        panelWindow.navigationState.holdProgress = 0
                        self.holdCompleted = false
                        self.holdStartTime = CACurrentMediaTime()

                        self.holdProgressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
                            guard let self = self, let panel = self.contentWindow as? ContentPanel else {
                                t.invalidate()
                                return
                            }
                            let elapsed = CACurrentMediaTime() - self.holdStartTime
                            let p = min(1.0, elapsed / self.holdDuration)
                            DispatchQueue.main.async {
                                panel.navigationState.holdProgress = p
                            }
                            if p >= 1.0 { t.invalidate(); self.holdProgressTimer = nil }
                        }
                        self.holdProgressTimer?.tolerance = 0.01
                        RunLoop.main.add(self.holdProgressTimer!, forMode: .common)

                        self.holdCompletionTimer = Timer.scheduledTimer(withTimeInterval: self.holdDuration, repeats: false) { [weak self] _ in
                            self?.completeHoldToEdit()
                        }
                        self.holdCompletionTimer?.tolerance = 0.02
                        RunLoop.main.add(self.holdCompletionTimer!, forMode: .common)
                        return nil
                    }

                    // Non-editable: normal press - toggle preview
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
            
            if event.type == .keyUp && event.keyCode == 49 {
                // Space key up - handle hold release (rebound) or consume after completed hold
                guard let panel = self.contentWindow as? ContentPanel else { return event }
                let wasHolding = panel.navigationState.isHoldingSpace || self.holdCompleted
                self.cancelHoldToEdit()
                if wasHolding {
                    if self.holdCompleted {
                        self.holdCompleted = false
                        return nil
                    }
                    // Early release: rebound (holdProgress already 0) then toggle preview
                    panel.navigationState.holdProgress = 0
                    if self.previewWindow?.isVisible == true {
                        self.closePreviewWindow()
                        self.contentWindow?.makeKey()
                    } else {
                        panel.navigationState.showPreview()
                    }
                    return nil
                }
                return event
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
                        // Close both preview and drawer when clicking outside the app
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
        // Don't close if the paste stack window or rich text editor windows are becoming key
        // But if clicking outside the app (not on preview, paste stack, or editor), close both preview and drawer
        if notification.object as? NSWindow == contentWindow {
            // Use a small delay to check which window becomes key (handles timing issues)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                guard let self = self else { return }
                
                // Check which window is now key
                let keyWindow = NSApplication.shared.keyWindow
                
                // If paste stack is becoming key, don't close
                if let pasteStack = self.pasteStackWindow, pasteStack.isVisible && keyWindow === pasteStack {
                    return
                }
                // If rich text editor is becoming key, don't close
                if let keyWin = keyWindow, self.richTextEditorWindows.contains(where: { $0 === keyWin }) {
                    return
                }
                // If preview is becoming key, don't close (user clicked on preview)
                if let preview = self.previewWindow, preview.isVisible && keyWindow === preview {
                    return
                }
                // Check if mouse is over preview window (fallback check)
                if let preview = self.previewWindow, preview.isVisible {
                    let mouseLocation = NSEvent.mouseLocation
                    let previewFrame = preview.frame
                    // NSEvent.mouseLocation uses bottom-left origin, same as NSWindow.frame
                    if previewFrame.contains(mouseLocation) {
                        return
                    }
                }
                // Otherwise, close both preview and drawer (clicked outside the app)
                self.closeReviewWindow(andPaste: false)
            }
        }
    }
    
    private func stopClickMonitoring() {
        cancelHoldToEdit()
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: contentWindow)
    }
    
    private func cancelHoldToEdit() {
        holdProgressTimer?.invalidate()
        holdProgressTimer = nil
        holdCompletionTimer?.invalidate()
        holdCompletionTimer = nil
        guard let panel = contentWindow as? ContentPanel else { return }
        panel.navigationState.isHoldingSpace = false
        panel.navigationState.holdProgress = 0
    }

    private func completeHoldToEdit() {
        holdProgressTimer?.invalidate()
        holdProgressTimer = nil
        holdCompletionTimer = nil
        holdCompleted = true
        guard let panel = contentWindow as? ContentPanel else { return }
        panel.navigationState.isHoldingSpace = false
        panel.navigationState.holdProgress = 0
        closePreviewWindow()
        openRichTextEditorForSelectedItem()
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
        
        // Start global click monitoring to detect clicks outside both preview and drawer
        startPreviewClickMonitoring()
    }
    
    func closePreviewWindow() {
        stopPreviewClickMonitoring()
        
        if let window = previewWindow {
            window.close()
            previewWindow = nil
        }
    }
    
    private func startPreviewClickMonitoring() {
        stopPreviewClickMonitoring() // Clean up any existing monitor first
        
        // Global monitor to detect clicks outside the app when preview is open
        previewClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self,
                  self.previewWindow?.isVisible == true else { return }
            
            // Get the window that received the click
            let clickWindow = event.window
            
            // Check if click is on one of our windows
            let isPreviewWindow = clickWindow === self.previewWindow
            let isDrawerWindow = clickWindow === self.contentWindow
            let isPasteStackWindow = clickWindow === self.pasteStackWindow
            let isRichTextEditorWindow = self.richTextEditorWindows.contains { $0 === clickWindow }
            
            // If click is outside all our windows, close both preview and drawer
            if !isPreviewWindow && !isDrawerWindow && !isPasteStackWindow && !isRichTextEditorWindow {
                DispatchQueue.main.async {
                    self.closeReviewWindow(andPaste: false)
                }
            }
        }
    }
    
    private func stopPreviewClickMonitoring() {
        if let monitor = previewClickMonitor {
            NSEvent.removeMonitor(monitor)
            previewClickMonitor = nil
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

        // Ensure app is activated and panel gets focus (needed for first item without prior navigation)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            editorPanel.makeFirstResponder(editorPanel.contentView)
            editorPanel.focusTextView()
        }
    }

    func removeRichTextEditorWindow(_ panel: RichTextEditorPanel) {
        richTextEditorWindows.removeAll { $0 === panel }
    }

    // MARK: - OCR Screen Capture

    private func setupOCRHotkey() {
        ocrHotKey = HotKey(key: .t, modifiers: [.command, .shift])
        ocrHotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.startScreenCapture()
            }
        }
    }

    func startScreenCapture() {
        // Close any open panels first
        closeReviewWindow(andPaste: false)
        closePasteStackWindow(andPaste: false)

        // Check for screen recording permission
        if !hasScreenRecordingPermission() {
            requestScreenRecordingPermission()
            return
        }

        // Get the main screen frame
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Create and show the capture panel
        let capturePanel = ScreenCapturePanel(screenFrame: screenFrame)
        capturePanel.onCapture = { [weak self] rect in
            self?.captureScreenRegion(rect)
            self?.screenCaptureWindow = nil
        }
        capturePanel.onCancel = { [weak self] in
            self?.screenCaptureWindow = nil
        }

        screenCaptureWindow = capturePanel
        capturePanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func captureScreenRegion(_ rect: NSRect) {
        // Get scale factor on main thread before async work
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0

        // Capture the screen region using ScreenCaptureKit
        Task {
            do {
                // Get shareable content
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                // Find the main display
                guard let display = content.displays.first(where: { display in
                    display.displayID == CGMainDisplayID()
                }) ?? content.displays.first else {
                    await MainActor.run {
                        self.showOCRError(.invalidImage)
                    }
                    return
                }

                // Find windows belonging to our app to exclude them
                let ourBundleID = Bundle.main.bundleIdentifier ?? ""
                let windowsToExclude = content.windows.filter { window in
                    window.owningApplication?.bundleIdentifier == ourBundleID
                }

                // Create a filter for the display, excluding our app's windows
                let filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)

                // Configure the capture
                let config = SCStreamConfiguration()
                config.sourceRect = rect
                config.width = Int(rect.width * scaleFactor)
                config.height = Int(rect.height * scaleFactor)
                config.scalesToFit = true
                config.showsCursor = false
                config.pixelFormat = kCVPixelFormatType_32BGRA

                // Capture the image
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                // Convert CGImage to NSImage
                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

                // Run OCR on main thread
                await MainActor.run {
                    OCRManager.shared.recognizeTextAsync(in: nsImage) { [weak self] result in
                        switch result {
                        case .success(let text):
                            self?.handleOCRResult(text)
                        case .failure(let error):
                            self?.showOCRError(error)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.showOCRError(.screenCaptureFailed(error))
                }
            }
        }
    }

    private func handleOCRResult(_ text: String) {
        // Copy text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Create a temporary ClipboardItem for the rich text editor
        let item = ClipboardItem(
            content: text,
            type: .text,
            sourceApp: SourceApp(
                bundleIdentifier: Bundle.main.bundleIdentifier,
                name: "Superclip OCR",
                icon: NSApp.applicationIconImage
            )
        )

        // Open rich text editor with the OCR result
        let editorFrame: NSRect
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth: CGFloat = 500
            let panelHeight: CGFloat = 400
            editorFrame = NSRect(
                x: screenFrame.midX - panelWidth / 2,
                y: screenFrame.midY - panelHeight / 2,
                width: panelWidth,
                height: panelHeight
            )
        } else {
            editorFrame = NSRect(x: 100, y: 100, width: 500, height: 400)
        }

        showRichTextEditorWindow(for: item, fromPreviewFrame: editorFrame)
    }

    private func showOCRError(_ error: OCRError) {
        let alert = NSAlert()
        alert.messageText = "OCR Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func hasScreenRecordingPermission() -> Bool {
        // Check if we have screen recording permission using CGPreflightScreenCaptureAccess
        return CGPreflightScreenCaptureAccess()
    }

    private func requestScreenRecordingPermission() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Superclip needs screen recording permission to capture screen regions for OCR.\n\nPlease grant permission in System Settings > Privacy & Security > Screen Recording."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings to Privacy & Security > Screen Recording
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
