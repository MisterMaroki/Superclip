//
//  ClipboardManager.swift
//  Superclip
//

import AppKit
import Combine

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    
    private var pasteboard: NSPasteboard
    private var changeCount: Int
    private var timer: Timer?
    private let maxHistorySize: Int = 100
    
    init() {
        pasteboard = NSPasteboard.general
        changeCount = pasteboard.changeCount
        
        // Start monitoring clipboard changes
        startMonitoring()
        
        // Load initial clipboard content
        loadCurrentClipboard()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        // Poll the pasteboard for changes every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        let currentChangeCount = pasteboard.changeCount
        
        if currentChangeCount != changeCount {
            changeCount = currentChangeCount
            loadCurrentClipboard()
        }
    }
    
    /// Get the frontmost application (the one that likely triggered the clipboard change)
    private func getFrontmostApp() -> SourceApp? {
        // Get the frontmost app that isn't our app
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            // If we are the frontmost, try to get the previously active app
            let runningApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
            }
            if let lastApp = runningApps.first {
                return SourceApp(
                    bundleIdentifier: lastApp.bundleIdentifier,
                    name: lastApp.localizedName ?? "Unknown",
                    icon: lastApp.icon
                )
            }
            return nil
        }
        
        return SourceApp(
            bundleIdentifier: frontApp.bundleIdentifier,
            name: frontApp.localizedName ?? "Unknown",
            icon: frontApp.icon
        )
    }
    
    private func loadCurrentClipboard() {
        let types = pasteboard.types ?? []
        let sourceApp = getFrontmostApp()
        
        // Check for images first (PNG, TIFF, etc.) - before files, since copied images
        // often have both image data and a file URL reference
        if types.contains(.png) || types.contains(.tiff) {
            if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
                // Create a description for the image
                var description = "Image"
                if let image = NSImage(data: imageData) {
                    description = "\(Int(image.size.width))×\(Int(image.size.height))"
                }
                addToHistory(item: ClipboardItem(
                    content: description,
                    type: .image,
                    imageData: imageData,
                    sourceApp: sourceApp
                ))
                return
            }
        }
        
        // Check for files
        if types.contains(.fileURL) {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
                // Check if it's a single image file - treat as image instead of file
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
                if urls.count == 1, let url = urls.first,
                   imageExtensions.contains(url.pathExtension.lowercased()),
                   let imageData = try? Data(contentsOf: url) {
                    var description = "Image"
                    if let image = NSImage(data: imageData) {
                        description = "\(Int(image.size.width))×\(Int(image.size.height))"
                    }
                    addToHistory(item: ClipboardItem(
                        content: description,
                        type: .image,
                        imageData: imageData,
                        fileURLs: urls,  // Keep file URL for reference
                        sourceApp: sourceApp
                    ))
                    return
                }
                
                let fileNames = urls.map { $0.lastPathComponent }.joined(separator: ", ")
                addToHistory(item: ClipboardItem(
                    content: fileNames,
                    type: .file,
                    fileURLs: urls,
                    sourceApp: sourceApp
                ))
                return
            }
        }
        
        // Check for URLs
        if types.contains(.URL) {
            if let url = pasteboard.string(forType: .URL), !url.isEmpty {
                addToHistory(item: ClipboardItem(content: url, type: .url, sourceApp: sourceApp))
                return
            }
        }
        
        // Check for RTF content
        if types.contains(.rtf) {
            if let rtfData = pasteboard.data(forType: .rtf),
               let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                let plainText = attributedString.string
                if !plainText.isEmpty {
                    addToHistory(item: ClipboardItem(content: plainText, type: .rtf, sourceApp: sourceApp))
                    return
                }
            }
        }
        
        // Check for plain string content
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Detect if it's a URL
            if let url = URL(string: string), url.scheme != nil {
                addToHistory(item: ClipboardItem(content: string, type: .url, sourceApp: sourceApp))
            } else {
                addToHistory(item: ClipboardItem(content: string, type: .text, sourceApp: sourceApp))
            }
        }
    }
    
    private func addToHistory(item: ClipboardItem) {
        let identifier = item.uniqueIdentifier
        
        // Check if already at front
        if let firstItem = history.first, firstItem.uniqueIdentifier == identifier {
            return
        }
        
        DispatchQueue.main.async {
            // Check if content already exists in history
            if let existingIndex = self.history.firstIndex(where: { $0.uniqueIdentifier == identifier }) {
                // Remove existing item and move to front with updated timestamp
                let existingItem = self.history.remove(at: existingIndex)
                let updatedItem = ClipboardItem(
                    id: existingItem.id,
                    content: existingItem.content,
                    timestamp: Date(),
                    type: existingItem.type,
                    imageData: existingItem.imageData,
                    fileURLs: existingItem.fileURLs,
                    sourceApp: existingItem.sourceApp
                )
                self.history.insert(updatedItem, at: 0)
            } else {
                // New item - insert at beginning
                self.history.insert(item, at: 0)
                
                // Limit history size
                if self.history.count > self.maxHistorySize {
                    self.history = Array(self.history.prefix(self.maxHistorySize))
                }
            }
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        
        switch item.type {
        case .image:
            if let imageData = item.imageData {
                // Try to determine the image type and set appropriate pasteboard type
                if let image = NSImage(data: imageData) {
                    pasteboard.writeObjects([image])
                }
            }
        case .file:
            if let urls = item.fileURLs {
                pasteboard.writeObjects(urls as [NSURL])
            }
        case .url:
            if let url = URL(string: item.content) {
                pasteboard.writeObjects([url as NSURL])
            }
            pasteboard.setString(item.content, forType: .string)
        case .text, .rtf:
            pasteboard.setString(item.content, forType: .string)
        }
        
        changeCount = pasteboard.changeCount
        
        // Move item to the front of the list (most recently used)
        DispatchQueue.main.async {
            // Remove the item from its current position
            self.history.removeAll { $0.id == item.id }
            
            // Create a new item with updated timestamp and insert at front
            let updatedItem = ClipboardItem(
                id: item.id,
                content: item.content,
                timestamp: Date(),
                type: item.type,
                imageData: item.imageData,
                fileURLs: item.fileURLs,
                sourceApp: item.sourceApp
            )
            self.history.insert(updatedItem, at: 0)
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            self.history.removeAll { $0.id == item.id }
        }
    }
    
    func updateItemContent(_ item: ClipboardItem, newContent: String) {
        DispatchQueue.main.async {
            if let index = self.history.firstIndex(where: { $0.id == item.id }) {
                let existingItem = self.history[index]
                let updatedItem = ClipboardItem(
                    id: existingItem.id,
                    content: newContent,
                    timestamp: existingItem.timestamp,
                    type: existingItem.type,
                    imageData: existingItem.imageData,
                    fileURLs: existingItem.fileURLs,
                    sourceApp: existingItem.sourceApp
                )
                self.history[index] = updatedItem
            }
        }
    }
    
    func clearHistory() {
        DispatchQueue.main.async {
            self.history.removeAll()
        }
    }
}
