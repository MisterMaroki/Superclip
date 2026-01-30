//
//  ClipboardManager.swift
//  Superclip
//

import AppKit
import Combine
import LinkPresentation

// Link metadata fetching service
class LinkMetadataService {
    static let shared = LinkMetadataService()
    private let cache = NSCache<NSURL, LinkMetadata>()
    
    private init() {}
    
    func fetchMetadata(for urlString: String, completion: @escaping (LinkMetadata?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // Check cache first
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        
        let provider = LPMetadataProvider()
        provider.timeout = 5.0
        
        provider.startFetchingMetadata(for: url) { [weak self] metadata, error in
            guard let metadata = metadata, error == nil else {
                // Create basic metadata without image
                let basicMetadata = LinkMetadata(title: nil, url: url, imageData: nil)
                DispatchQueue.main.async {
                    completion(basicMetadata)
                }
                return
            }
            
            // Fetch the image if available
            if let imageProvider = metadata.imageProvider {
                imageProvider.loadObject(ofClass: NSImage.self) { image, _ in
                    let linkMetadata: LinkMetadata
                    if let nsImage = image as? NSImage,
                       let imageData = nsImage.tiffRepresentation {
                        linkMetadata = LinkMetadata(
                            title: metadata.title,
                            url: url,
                            imageData: imageData
                        )
                    } else {
                        linkMetadata = LinkMetadata(
                            title: metadata.title,
                            url: url,
                            imageData: nil
                        )
                    }
                    
                    self?.cache.setObject(linkMetadata, forKey: url as NSURL)
                    
                    DispatchQueue.main.async {
                        completion(linkMetadata)
                    }
                }
            } else {
                let linkMetadata = LinkMetadata(title: metadata.title, url: url, imageData: nil)
                self?.cache.setObject(linkMetadata, forKey: url as NSURL)
                
                DispatchQueue.main.async {
                    completion(linkMetadata)
                }
            }
        }
    }
}

// Struct to track deleted items for undo
struct DeletedItemRecord {
    let item: ClipboardItem
    let index: Int
    let timestamp: Date
}

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    
    private var pasteboard: NSPasteboard
    private var changeCount: Int
    private var timer: Timer?
    private let maxHistorySize: Int = 100
    
    // Undo support - keep deleted items for a short period
    private var deletedItems: [DeletedItemRecord] = []
    private let undoTimeout: TimeInterval = 30.0 // 30 seconds to undo
    private var undoCleanupTimer: Timer?
    
    init() {
        pasteboard = NSPasteboard.general
        changeCount = pasteboard.changeCount
        
        // Start monitoring clipboard changes
        startMonitoring()
        
        // Start undo cleanup timer
        startUndoCleanupTimer()
        
        // Load initial clipboard content
        loadCurrentClipboard()
    }
    
    deinit {
        stopMonitoring()
        undoCleanupTimer?.invalidate()
    }
    
    private func startUndoCleanupTimer() {
        // Clean up old deleted items every 10 seconds
        undoCleanupTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.cleanupExpiredDeletedItems()
        }
    }
    
    private func cleanupExpiredDeletedItems() {
        let now = Date()
        deletedItems.removeAll { now.timeIntervalSince($0.timestamp) > undoTimeout }
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
            if let url = pasteboard.string(forType: .URL)?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
                addToHistory(item: ClipboardItem(content: url, type: .url, sourceApp: sourceApp))
                return
            }
        }
        
        
        // Check for plain string content
        if let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            // Detect if it's a URL
            // Real URLs don't contain unencoded whitespace, so skip URL detection if string has spaces
            let containsWhitespace = string.rangeOfCharacter(from: .whitespaces) != nil
            if !containsWhitespace, let url = URL(string: string), url.scheme != nil || string.contains(".") {
                // Has a scheme (http://...) or looks like a domain (google.com)
                // Validate domain-like strings by checking they have valid URL structure
                let urlString = url.scheme != nil ? string : "https://\(string)"
                if let validatedURL = URL(string: urlString), validatedURL.host != nil {
                    addToHistory(item: ClipboardItem(content: string, type: .url, sourceApp: sourceApp))
                } else {
                    addToHistory(item: ClipboardItem(content: string, type: .text, sourceApp: sourceApp))
                }
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
                    sourceApp: existingItem.sourceApp,
                    linkMetadata: existingItem.linkMetadata,
                    rtfData: existingItem.rtfData
                )
                self.history.insert(updatedItem, at: 0)
            } else {
                // New item - insert at beginning
                self.history.insert(item, at: 0)
                
                // If it's a URL, fetch link metadata
                if item.type == .url {
                    self.fetchLinkMetadata(for: item)
                }
                
                // Limit history size
                if self.history.count > self.maxHistorySize {
                    self.history = Array(self.history.prefix(self.maxHistorySize))
                }
            }
        }
    }
    
    private func fetchLinkMetadata(for item: ClipboardItem) {
        LinkMetadataService.shared.fetchMetadata(for: item.content) { [weak self] metadata in
            guard let self = self, let metadata = metadata else { return }
            
            DispatchQueue.main.async {
                if let index = self.history.firstIndex(where: { $0.id == item.id }) {
                    var updatedItem = self.history[index]
                    updatedItem.linkMetadata = metadata
                    self.history[index] = updatedItem
                }
            }
        }
    }
    
    func copyAsPlainText(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        changeCount = pasteboard.changeCount

        DispatchQueue.main.async {
            self.history.removeAll { $0.id == item.id }
            let updatedItem = ClipboardItem(
                id: item.id,
                content: item.content,
                timestamp: Date(),
                type: item.type,
                imageData: item.imageData,
                fileURLs: item.fileURLs,
                sourceApp: item.sourceApp,
                linkMetadata: item.linkMetadata,
                rtfData: item.rtfData
            )
            self.history.insert(updatedItem, at: 0)
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
        case .text:
            // If item has rich text formatting, include RTF data
            if let rtfData = item.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            // Always include plain text as fallback
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
                sourceApp: item.sourceApp,
                linkMetadata: item.linkMetadata,
                rtfData: item.rtfData
            )
            self.history.insert(updatedItem, at: 0)
        }
    }
    
    func copyToClipboardAsPlainText(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        changeCount = pasteboard.changeCount
    }

    func deleteItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            // Find the index before removing
            if let index = self.history.firstIndex(where: { $0.id == item.id }) {
                // Store for undo
                let record = DeletedItemRecord(item: item, index: index, timestamp: Date())
                self.deletedItems.append(record)
                
                // Remove from history
                self.history.remove(at: index)
            }
        }
    }
    
    /// Returns true if there are items that can be undone
    var canUndo: Bool {
        !deletedItems.isEmpty
    }
    
    /// Undo the last deletion
    func undoDelete() {
        DispatchQueue.main.async {
            guard let lastDeleted = self.deletedItems.popLast() else { return }
            
            // Check if the undo hasn't expired
            if Date().timeIntervalSince(lastDeleted.timestamp) <= self.undoTimeout {
                // Insert back at the original position (or at the end if history is shorter now)
                let insertIndex = min(lastDeleted.index, self.history.count)
                self.history.insert(lastDeleted.item, at: insertIndex)
            }
        }
    }
    
    /// Determine if a string should be treated as a URL
    private func isValidURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Real URLs don't contain unencoded whitespace
        let containsWhitespace = trimmed.rangeOfCharacter(from: .whitespaces) != nil
        guard !containsWhitespace else { return false }

        if let url = URL(string: trimmed), url.scheme != nil || trimmed.contains(".") {
            // Has a scheme (http://...) or looks like a domain (google.com)
            let urlString = url.scheme != nil ? trimmed : "https://\(trimmed)"
            if let validatedURL = URL(string: urlString), validatedURL.host != nil {
                return true
            }
        }
        return false
    }

    func updateItemContent(_ item: ClipboardItem, newContent: String) {
        DispatchQueue.main.async {
            if let index = self.history.firstIndex(where: { $0.id == item.id }) {
                let existingItem = self.history[index]
                let trimmedContent = newContent.trimmingCharacters(in: .whitespacesAndNewlines)

                // Re-evaluate if content is a URL
                let newType: ClipboardItem.ClipboardType = self.isValidURL(trimmedContent) ? .url : .text

                // Clear metadata if no longer a URL, or fetch new metadata if became a URL
                let newMetadata: LinkMetadata? = (newType == .url) ? existingItem.linkMetadata : nil

                let updatedItem = ClipboardItem(
                    id: existingItem.id,
                    content: trimmedContent,
                    timestamp: existingItem.timestamp,
                    type: newType,
                    imageData: existingItem.imageData,
                    fileURLs: existingItem.fileURLs,
                    sourceApp: existingItem.sourceApp,
                    linkMetadata: newMetadata,
                    rtfData: existingItem.rtfData
                )
                self.history[index] = updatedItem

                // If it became a URL or URL changed, fetch new metadata
                if newType == .url && (existingItem.type != .url || existingItem.content != trimmedContent) {
                    self.fetchLinkMetadata(for: updatedItem)
                }
            }
        }
    }

    func updateItemRichContent(_ item: ClipboardItem, attributedString: NSAttributedString) {
        DispatchQueue.main.async {
            if let index = self.history.firstIndex(where: { $0.id == item.id }) {
                let existingItem = self.history[index]
                // Convert attributed string to RTF data
                let rtfData = try? attributedString.data(
                    from: NSRange(location: 0, length: attributedString.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
                // Also update plain text content
                let plainText = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)

                // Re-evaluate if content is a URL
                let newType: ClipboardItem.ClipboardType = self.isValidURL(plainText) ? .url : .text

                // Clear metadata if no longer a URL
                let newMetadata: LinkMetadata? = (newType == .url) ? existingItem.linkMetadata : nil

                let updatedItem = ClipboardItem(
                    id: existingItem.id,
                    content: plainText,
                    timestamp: existingItem.timestamp,
                    type: newType,
                    imageData: existingItem.imageData,
                    fileURLs: existingItem.fileURLs,
                    sourceApp: existingItem.sourceApp,
                    linkMetadata: newMetadata,
                    rtfData: rtfData
                )
                self.history[index] = updatedItem

                // If it became a URL or URL changed, fetch new metadata
                if newType == .url && (existingItem.type != .url || existingItem.content != plainText) {
                    self.fetchLinkMetadata(for: updatedItem)
                }
            }
        }
    }
    
    func clearHistory() {
        DispatchQueue.main.async {
            self.history.removeAll()
        }
    }
}
