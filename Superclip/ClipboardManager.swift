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

      let title = metadata.title

      // Helper to load NSImage data from an NSItemProvider
      func loadImageData(from provider: NSItemProvider?, completion: @escaping (Data?) -> Void) {
        guard let provider = provider else {
          completion(nil)
          return
        }
        provider.loadObject(ofClass: NSImage.self) { object, _ in
          if let nsImage = object as? NSImage, let data = nsImage.tiffRepresentation {
            completion(data)
          } else {
            completion(nil)
          }
        }
      }

      // Load image first, then icon as fallback
      loadImageData(from: metadata.imageProvider) { imageData in
        loadImageData(from: metadata.iconProvider) { iconData in
          let linkMetadata = LinkMetadata(
            title: title,
            url: url,
            imageData: imageData,
            iconData: iconData
          )
          self?.cache.setObject(linkMetadata, forKey: url as NSURL)
          DispatchQueue.main.async {
            completion(linkMetadata)
          }
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
  let settings: SettingsManager
  private var cancellables = Set<AnyCancellable>()

  // Undo support - keep deleted items for a short period
  private var deletedItems: [DeletedItemRecord] = []
  private let undoTimeout: TimeInterval = 30.0  // 30 seconds to undo
  private var undoCleanupTimer: Timer?

  // Persistence
  let historyStore = HistoryStore()

  init(settings: SettingsManager) {
    self.settings = settings
    pasteboard = NSPasteboard.general
    changeCount = pasteboard.changeCount

    // Load persisted history from disk before anything else
    let loaded = historyStore.load()
    if !loaded.isEmpty {
      history = loaded
    }

    // Start monitoring clipboard changes (if enabled)
    if settings.monitorClipboard {
      startMonitoring()
    }

    // Start undo cleanup timer
    startUndoCleanupTimer()

    // Load initial clipboard content (picks up whatever is currently on the pasteboard)
    loadCurrentClipboard()

    // Observe settings changes
    observeSettings()

    // Auto-save: observe history changes and schedule debounced writes
    observeHistoryForPersistence()

    // Re-fetch link metadata for URL items loaded from disk (metadata is not persisted)
    if settings.detectLinks {
      refetchLinkMetadataForLoadedItems()
    }
  }

  deinit {
    stopMonitoring()
    undoCleanupTimer?.invalidate()
    cancellables.removeAll()
  }

  // MARK: - Persistence Helpers

  /// Observe `$history` and schedule a debounced save on every change.
  private func observeHistoryForPersistence() {
    $history
      .dropFirst()  // Skip the initial value (already loaded or empty)
      .sink { [weak self] items in
        self?.historyStore.scheduleSave(items: items)
      }
      .store(in: &cancellables)
  }

  /// Immediately flush history to disk. Call on app termination.
  func saveHistoryImmediately() {
    historyStore.saveImmediately(items: history)
  }

  /// Re-fetch link metadata for URL items loaded from disk (metadata is intentionally not persisted).
  private func refetchLinkMetadataForLoadedItems() {
    for item in history where item.type == .url && item.linkMetadata == nil {
      fetchLinkMetadata(for: item)
    }
  }

  private func observeSettings() {
    settings.$monitorClipboard
      .dropFirst()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] enabled in
        if enabled {
          self?.startMonitoring()
        } else {
          self?.stopMonitoring()
        }
      }
      .store(in: &cancellables)

    settings.$maxHistorySize
      .dropFirst()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] newSize in
        guard let self = self else { return }
        if newSize > 0 && self.history.count > newSize {
          self.history = Array(self.history.prefix(newSize))
        }
      }
      .store(in: &cancellables)
  }

  private func startUndoCleanupTimer() {
    // Clean up old deleted items every 10 seconds
    undoCleanupTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) {
      [weak self] _ in
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
      frontApp.bundleIdentifier != Bundle.main.bundleIdentifier
    else {
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

    // Check if the source app is in the ignored list
    if settings.isAppIgnored(bundleIdentifier: sourceApp?.bundleIdentifier) {
      return
    }

    // Check for confidential content (e.g. password manager entries)
    if settings.ignoreConfidentialContent,
      types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    {
      return
    }

    // Check for transient content (e.g. auto-generated temporary data)
    if settings.ignoreTransientContent,
      types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
    {
      return
    }

    // Check for images first (PNG, TIFF, etc.) - before files, since copied images
    // often have both image data and a file URL reference
    if types.contains(.png) || types.contains(.tiff) {
      if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
        // Create a description for the image
        var description = "Image"
        if let image = NSImage(data: imageData) {
          description = "\(Int(image.size.width))×\(Int(image.size.height))"
        }
        addToHistory(
          item: ClipboardItem(
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
      if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
        !urls.isEmpty
      {
        // Check if it's a single image file - treat as image instead of file
        let imageExtensions = [
          "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif",
        ]
        if urls.count == 1, let url = urls.first,
          imageExtensions.contains(url.pathExtension.lowercased()),
          let imageData = try? Data(contentsOf: url)
        {
          var description = "Image"
          if let image = NSImage(data: imageData) {
            description = "\(Int(image.size.width))×\(Int(image.size.height))"
          }
          addToHistory(
            item: ClipboardItem(
              content: description,
              type: .image,
              imageData: imageData,
              fileURLs: urls,  // Keep file URL for reference
              sourceApp: sourceApp
            ))
          return
        }

        let fileNames = urls.map { $0.lastPathComponent }.joined(separator: ", ")
        addToHistory(
          item: ClipboardItem(
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
      if let url = pasteboard.string(forType: .URL)?.trimmingCharacters(
        in: .whitespacesAndNewlines), !url.isEmpty
      {
        addToHistory(item: ClipboardItem(content: url, type: .url, sourceApp: sourceApp))
        return
      }
    }

    // Check for plain string content
    if let string = pasteboard.string(forType: .string)?.trimmingCharacters(
      in: .whitespacesAndNewlines), !string.isEmpty
    {
      // Detect if it's a URL
      // Real URLs don't contain unencoded whitespace, so skip URL detection if string has spaces
      let containsWhitespace = string.rangeOfCharacter(from: .whitespaces) != nil
      // Email addresses like user@example.com parse as valid URLs (user@ becomes HTTP auth)
      // but should be treated as text, not links
      let looksLikeEmail =
        string.range(
          of: #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#,
          options: .regularExpression) != nil
      if !containsWhitespace, !looksLikeEmail, let url = URL(string: string),
        url.scheme != nil || string.contains(".")
      {
        // Has a scheme (http://...) or looks like a domain (google.com)
        // Validate domain-like strings by checking they have valid URL structure
        // Reject schemeless strings starting with "." (e.g. ".hidden-file") — not valid domains
        let urlString = url.scheme != nil ? string : "https://\(string)"
        if url.scheme != nil || !string.hasPrefix("."),
          let validatedURL = URL(string: urlString), validatedURL.host != nil
        {
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

    // Auto-detect content tags for text-based items
    var taggedItem = item
    if item.type == .text || item.type == .url {
      taggedItem = ClipboardItem(
        id: item.id,
        content: item.content,
        timestamp: item.timestamp,
        type: item.type,
        imageData: item.imageData,
        fileURLs: item.fileURLs,
        sourceApp: item.sourceApp,
        linkMetadata: item.linkMetadata,
        rtfData: item.rtfData,
        detectedTags: ContentDetector.detect(text: item.content)
      )
    }

    DispatchQueue.main.async {
      // Check if content already exists in history (dedup logic)
      if self.settings.deduplicateItems,
        let existingIndex = self.history.firstIndex(where: { $0.uniqueIdentifier == identifier })
      {
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
          rtfData: existingItem.rtfData,
          detectedTags: existingItem.detectedTags
        )
        self.history.insert(updatedItem, at: 0)
      } else {
        // New item - insert at beginning
        self.history.insert(taggedItem, at: 0)

        // If it's a URL, fetch link metadata (if enabled)
        if taggedItem.type == .url && self.settings.detectLinks {
          self.fetchLinkMetadata(for: taggedItem)
        }

        // Limit history size (0 = unlimited)
        let maxSize = self.settings.maxHistorySize
        if maxSize > 0 && self.history.count > maxSize {
          self.history = Array(self.history.prefix(maxSize))
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
        rtfData: item.rtfData,
        detectedTags: item.detectedTags
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
        rtfData: item.rtfData,
        detectedTags: item.detectedTags
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

    // Email addresses parse as valid URLs (user@ becomes HTTP auth) but are not URLs
    let looksLikeEmail =
      trimmed.range(
        of: #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#,
        options: .regularExpression) != nil
    guard !looksLikeEmail else { return false }

    if let url = URL(string: trimmed), url.scheme != nil || trimmed.contains(".") {
      // Has a scheme (http://...) or looks like a domain (google.com)
      // Reject schemeless strings starting with "." (e.g. ".hidden-file") — not valid domains
      let urlString = url.scheme != nil ? trimmed : "https://\(trimmed)"
      if url.scheme != nil || !trimmed.hasPrefix("."),
        let validatedURL = URL(string: urlString), validatedURL.host != nil
      {
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

        // Re-detect content tags for the updated content
        let newTags = ContentDetector.detect(text: trimmedContent)

        let updatedItem = ClipboardItem(
          id: existingItem.id,
          content: trimmedContent,
          timestamp: existingItem.timestamp,
          type: newType,
          imageData: existingItem.imageData,
          fileURLs: existingItem.fileURLs,
          sourceApp: existingItem.sourceApp,
          linkMetadata: newMetadata,
          rtfData: existingItem.rtfData,
          detectedTags: newTags
        )
        self.history[index] = updatedItem

        // If it became a URL or URL changed, fetch new metadata
        if newType == .url && (existingItem.type != .url || existingItem.content != trimmedContent)
        {
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

        // Re-detect content tags for the updated content
        let newTags = ContentDetector.detect(text: plainText)

        let updatedItem = ClipboardItem(
          id: existingItem.id,
          content: plainText,
          timestamp: existingItem.timestamp,
          type: newType,
          imageData: existingItem.imageData,
          fileURLs: existingItem.fileURLs,
          sourceApp: existingItem.sourceApp,
          linkMetadata: newMetadata,
          rtfData: rtfData,
          detectedTags: newTags
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
      // Also delete the persisted file so cleared history doesn't come back
      self.historyStore.deleteHistoryFile()
    }
  }

  /// Seeds tutorial cards into history. Returns the ID of the card that should be pinned to Favorites.
  @discardableResult
  func seedTutorialItems() -> UUID? {
    // Display order is reversed — last element ends up at index 0 (leftmost).
    // First element in this array ends up rightmost in the drawer.
    let texts = [
      // Rightmost — lives in the Favorites pinboard for when they Cmd+Right over
      "Look at you, nailing it already! This is your Favorites pinboard — your VIP section for clips you want to keep forever. Drag cards here or right-click \u{2192} Pin.",
      // Tour finale — tells them to hop to the pinboard
      "Almost done! Now hold Cmd, then press \u{2192} to see your Favorites pinboard. Go on, we\u{2019}ll wait.",
      "Right-click a pinboard to rename it or change its color",
      "Drag cards onto a pinboard to save them, or right-click \u{2192} Pin",
      "Cmd+Shift+C starts a paste stack — paste items one by one with Cmd+V, and it auto-advances",
      "Cmd+Shift+` opens Text Sniper — grab text from anywhere on screen like magic",
      // The surprise card — card shows the first line, editor reveals the rest
      "Hold Space on this card for a surprise\n\n\n\n\n\n\n\nSurprise! This is the rich text editor. Bold, italic, lists — perfect for cleaning up text before you paste it.",
      "Press Space to preview this card — works for images, links, and files too",
      "Right-click this card to see quick actions like copy, pin, and delete",
      "Press Backspace to toss this card — hit Cmd+Z if you change your mind",
      "Start typing anything to search — no need to click a search box",
      // Second card — encouragement
      "Nice one! Keep pressing \u{2192} to continue the tour",
      // Leftmost — first card the user sees
      "Welcome to Superclip! Press \u{2192} to start the tour",
    ]

    let sourceApp = SourceApp(
      bundleIdentifier: Bundle.main.bundleIdentifier,
      name: "Superclip",
      icon: NSApp.applicationIconImage
    )

    let now = Date()
    var pinCardId: UUID?
    for (index, text) in texts.enumerated() {
      let item = ClipboardItem(
        content: text,
        timestamp: now.addingTimeInterval(Double(index)),
        type: .text,
        sourceApp: sourceApp
      )
      history.insert(item, at: 0)
      // First element = rightmost card = the one to pin
      if index == 0 {
        pinCardId = item.id
      }
    }
    return pinCardId
  }
}
