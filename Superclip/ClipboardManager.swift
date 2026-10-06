//
//  ClipboardManager.swift
//  Superclip
//

import AppKit
import Combine
import ImageIO
import LinkPresentation

// Link metadata fetching service
class LinkMetadataService {
  static let shared = LinkMetadataService()
  private let cache = NSCache<NSURL, LinkMetadata>()
  /// Completions waiting on a fetch that is already running, keyed by URL.
  /// Main thread only.
  private var waiting: [URL: [(LinkMetadata?) -> Void]] = [:]

  private init() {}

  /// Re-encode a preview image small. `tiffRepresentation` of a typical
  /// 1200x630 preview is about 3 MB on disk and has to be read and decoded in
  /// full for every card; a 600px JPEG is a few dozen KB.
  static func compactImageData(from image: NSImage, maxPixel: CGFloat, keepAlpha: Bool) -> Data? {
    guard let tiff = image.tiffRepresentation,
      let source = CGImageSourceCreateWithData(tiff as CFData, nil)
    else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceThumbnailMaxPixelSize: maxPixel,
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
    ]
    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      return tiff
    }
    let rep = NSBitmapImageRep(cgImage: cg)
    if keepAlpha {
      return rep.representation(using: .png, properties: [:]) ?? tiff
    }
    return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) ?? tiff
  }

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

    // One fetch per URL at a time: a card that scrolls out and back in, or a
    // drawer reopened mid-fetch, joins the request already in flight.
    if waiting[url] != nil {
      waiting[url]?.append(completion)
      return
    }
    waiting[url] = [completion]
    let finish: (LinkMetadata?) -> Void = { [weak self] result in
      DispatchQueue.main.async {
        let callbacks = self?.waiting.removeValue(forKey: url) ?? []
        callbacks.forEach { $0(result) }
      }
    }

    let provider = LPMetadataProvider()
    provider.timeout = 5.0

    provider.startFetchingMetadata(for: url) { [weak self] metadata, error in
      guard let metadata = metadata, error == nil else {
        // Create basic metadata without image
        finish(LinkMetadata(title: nil, url: url))
        return
      }

      let title = metadata.title

      // Helper to load NSImage data from an NSItemProvider
      func loadImageData(
        from provider: NSItemProvider?, maxPixel: CGFloat, keepAlpha: Bool,
        completion: @escaping (Data?) -> Void
      ) {
        guard let provider = provider else {
          completion(nil)
          return
        }
        provider.loadObject(ofClass: NSImage.self) { object, _ in
          if let nsImage = object as? NSImage,
            let data = LinkMetadataService.compactImageData(
              from: nsImage, maxPixel: maxPixel, keepAlpha: keepAlpha)
          {
            completion(data)
          } else {
            completion(nil)
          }
        }
      }

      // Load image first, then icon as fallback.
      // The LinkMetadata convenience init persists image/icon data to disk
      // so they don't live in memory.
      loadImageData(from: metadata.imageProvider, maxPixel: 640, keepAlpha: false) { imageData in
        loadImageData(from: metadata.iconProvider, maxPixel: 128, keepAlpha: true) { iconData in
          let linkMeta = LinkMetadata(
            title: title,
            url: url,
            imageData: imageData,
            iconData: iconData
          )
          self?.cache.setObject(linkMeta, forKey: url as NSURL)
          finish(linkMeta)
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
  @Published var history: [ClipboardItem] = [] {
    didSet { historyVersion &+= 1 }
  }

  /// Bumped on every change to `history`. Lets views cache work derived from
  /// history (filtering, search) and know cheaply whether it is still valid.
  private(set) var historyVersion: Int = 0

  private var pasteboard: NSPasteboard
  private var changeCount: Int
  private var timer: Timer?
  let settings: SettingsManager
  private var cancellables = Set<AnyCancellable>()

  // Undo support - keep deleted items for a short period
  private var deletedItems: [DeletedItemRecord] = []
  private let undoTimeout: TimeInterval = 30.0  // 30 seconds to undo
  private var undoCleanupTimer: Timer?

  // O(1) dedup lookup — mirrors the uniqueIdentifiers present in `history`
  private var knownIdentifiers = Set<String>()

  /// Returns true for items that must survive history trimming (e.g. pinned
  /// to a pinboard). Set by the AppDelegate once managers are wired up.
  var isItemProtected: ((UUID) -> Bool)?

  /// Called with the IDs of items that are gone for good (a delete whose undo
  /// window has closed), so pinboards can drop their references to them.
  var onItemsPurged: (([UUID]) -> Void)?

  /// Emits each item that arrives through a real pasteboard capture (a copy
  /// the user made), after it has been placed in `history`. Superclip's own
  /// pasteboard writes and history reordering never emit here, so observers
  /// such as the paste stack can tell "the user copied something" apart from
  /// "history changed".
  let captured = PassthroughSubject<ClipboardItem, Never>()

  // Persistence
  let historyStore = HistoryStore()

  /// - Parameter pasteboard: the pasteboard to watch and write. Always the
  ///   general pasteboard in the app; tests pass a private one so they never
  ///   read or overwrite the real clipboard.
  init(settings: SettingsManager, pasteboard: NSPasteboard = .general) {
    self.settings = settings
    self.pasteboard = pasteboard
    changeCount = pasteboard.changeCount

    // Load persisted history from disk before anything else
    let loaded = historyStore.load()
    if !loaded.isEmpty {
      history = loaded
      knownIdentifiers = Set(loaded.map(\.uniqueIdentifier))
    }

    // Start monitoring clipboard changes (if enabled)
    if settings.monitorClipboard {
      startMonitoring()
      // Load initial clipboard content (picks up whatever is currently on the
      // pasteboard). Only when monitoring is on — capturing at launch while
      // the user has monitoring disabled is a privacy violation.
      loadCurrentClipboard()
    }

    // Observe settings changes
    observeSettings()

    // Auto-save: observe history changes and schedule debounced writes
    observeHistoryForPersistence()

    // Link metadata is fetched lazily via ensureLinkMetadata(_:) when items
    // become visible, instead of re-fetching all URL items at startup.

    // Clean up orphaned image/RTF files — defer to let addToHistory settle first
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let validIDs = Set(self.history.map(\.id))
      let linkURLs = self.history.filter { $0.type == .url }.compactMap { URL(string: $0.content) }
      DispatchQueue.global(qos: .utility).async {
        ImageStore.shared.cleanupOrphans(keeping: validIDs)
        RTFStore.shared.cleanupOrphans(keeping: validIDs)
        LinkImageStore.shared.cleanupOrphans(keeping: linkURLs)
      }
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

  /// Lazy link metadata: fetch only when the card becomes visible.
  /// Call from the view layer when a URL item is about to appear on screen.
  func ensureLinkMetadata(_ item: ClipboardItem) {
    guard settings.detectLinks, item.type == .url, item.linkMetadata == nil else { return }
    fetchLinkMetadata(for: item)
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
        self?.trimHistory(to: newSize)
      }
      .store(in: &cancellables)
  }

  /// Trim history to `maxSize`, oldest first, skipping pinned items —
  /// pinboards reference history items by ID, so trimming a pinned item
  /// would silently destroy content the user chose to keep.
  private func trimHistory(to maxSize: Int) {
    guard maxSize > 0, history.count > maxSize else { return }
    var overflow = history.count - maxSize
    var index = history.count - 1
    while overflow > 0 && index >= 0 {
      let item = history[index]
      if isItemProtected?(item.id) != true {
        knownIdentifiers.remove(item.uniqueIdentifier)
        if item.hasImage { ImageStore.shared.delete(for: item.id) }
        if item.hasRTF   { RTFStore.shared.delete(for: item.id) }
        history.remove(at: index)
        overflow -= 1
      }
      index -= 1
    }
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
    let expired = deletedItems.filter { now.timeIntervalSince($0.timestamp) > undoTimeout }
    for record in expired {
      if record.item.hasImage { ImageStore.shared.delete(for: record.item.id) }
      if record.item.hasRTF   { RTFStore.shared.delete(for: record.item.id) }
    }
    deletedItems.removeAll { now.timeIntervalSince($0.timestamp) > undoTimeout }
    if !expired.isEmpty {
      onItemsPurged?(expired.map(\.item.id))
    }

    // Stop timer when no deleted items remain
    if deletedItems.isEmpty {
      undoCleanupTimer?.invalidate()
      undoCleanupTimer = nil
    }
  }

  /// Seconds between pasteboard polls. The paste stack shortens it while a
  /// session is open, because the order of rapid copies matters there.
  private var pollInterval: TimeInterval = 0.5

  private func startMonitoring() {
    // Resync first: whatever was copied while monitoring was off must not be
    // captured the moment it is switched back on.
    changeCount = pasteboard.changeCount
    schedulePollTimer()
  }

  private func schedulePollTimer() {
    timer?.invalidate()
    let newTimer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
      self?.checkClipboard()
    }
    newTimer.tolerance = pollInterval * 0.2
    // Common modes: keep capturing while a menu is open or a control is tracking
    RunLoop.main.add(newTimer, forMode: .common)
    timer = newTimer
  }

  /// Poll faster (paste stack session) or at the normal rate.
  func setFastPolling(_ fast: Bool) {
    let interval: TimeInterval = fast ? 0.12 : 0.5
    guard interval != pollInterval else { return }
    pollInterval = interval
    if timer != nil { schedulePollTimer() }
  }

  /// Check the pasteboard right now instead of waiting for the next poll.
  func checkClipboardNow() {
    guard timer != nil else { return }  // monitoring is off
    checkClipboard()
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
        // Hash + write off the main thread: a large image (a 5K screenshot is
        // tens of MB as TIFF) would otherwise stall the app inside the poll timer.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
          // Read dimensions from the compressed header — NSImage(data:) fully
          // decodes the bitmap just to answer a size question.
          var item = ClipboardItem(
            content: Self.imageDescription(from: imageData),
            type: .image,
            imageData: imageData,
            sourceApp: sourceApp
          )
          ImageStore.shared.save(data: imageData, for: item.id)
          item.imageData = nil  // Release in-memory bytes; load from disk on demand
          DispatchQueue.main.async {
            self?.addToHistory(item: item)
          }
        }
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
          imageExtensions.contains(url.pathExtension.lowercased())
        {
          // Read + hash the file off the main thread — a large image file
          // would otherwise beachball the whole app inside the poll timer.
          DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let imageData = try? Data(contentsOf: url) else { return }
            var item = ClipboardItem(
              content: Self.imageDescription(from: imageData),
              type: .image,
              imageData: imageData,
              fileURLs: urls,  // Keep file URL for reference
              sourceApp: sourceApp
            )
            ImageStore.shared.save(data: imageData, for: item.id)
            item.imageData = nil  // Release in-memory bytes; load from disk on demand
            DispatchQueue.main.async {
              self.addToHistory(item: item)
            }
          }
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
        in: .whitespacesAndNewlines), !url.isEmpty, isValidURL(url)
      {
        addToHistory(item: ClipboardItem(content: url, type: .url, sourceApp: sourceApp))
        return
      }
    }

    // Check for plain string content
    if let raw = pasteboard.string(forType: .string) {
      let string = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !string.isEmpty else { return }
      // Detect if it's a URL
      // Real URLs don't contain unencoded whitespace, so skip URL detection if string has spaces
      let containsWhitespace = string.rangeOfCharacter(from: .whitespaces) != nil
      // Email addresses like user@example.com parse as valid URLs (user@ becomes HTTP auth)
      // but should be treated as text, not links
      let looksLikeEmail =
        string.range(
          of: #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#,
          options: .regularExpression) != nil
      if !containsWhitespace, !looksLikeEmail, isValidURL(string) {
        addToHistory(item: ClipboardItem(content: string, type: .url, sourceApp: sourceApp))
      } else {
        // Store text exactly as copied. Trimming it here meant an indented
        // line or a trailing newline came back different when pasted from history.
        addToHistory(item: ClipboardItem(content: raw, type: .text, sourceApp: sourceApp))
      }
    }
  }

  func addToHistory(item: ClipboardItem) {
    let identifier = item.uniqueIdentifier

    // Check if already at front
    if let firstItem = history.first, firstItem.uniqueIdentifier == identifier {
      deleteStores(forDiscarded: item, keptId: firstItem.id)
      // Bump the timestamp so the re-copy registers as recent activity and
      // observers (e.g. an active paste stack) see a change event for it.
      DispatchQueue.main.async {
        if let current = self.history.first, current.uniqueIdentifier == identifier {
          self.history[0] = ClipboardItem(
            id: current.id,
            content: current.content,
            timestamp: Date(),
            type: current.type,
            imageData: current.imageData,
            hasImage: current.hasImage,
            imageHash: current.imageHash,
            fileURLs: current.fileURLs,
            sourceApp: current.sourceApp,
            linkMetadata: current.linkMetadata,
            hasRTF: current.hasRTF,
            detectedTags: current.detectedTags
          )
          self.captured.send(self.history[0])
        }
      }
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
        hasImage: item.hasImage,
        imageHash: item.imageHash,
        fileURLs: item.fileURLs,
        sourceApp: item.sourceApp,
        linkMetadata: item.linkMetadata,
        hasRTF: item.hasRTF,
        detectedTags: ContentDetector.detect(text: item.content)
      )
    }

    DispatchQueue.main.async {
      // Check if content already exists in history (dedup logic)
      if self.settings.deduplicateItems,
        self.knownIdentifiers.contains(identifier),
        let existingIndex = self.history.firstIndex(where: { $0.uniqueIdentifier == identifier })
      {
        // Move the existing item to the front with an updated timestamp.
        // Work on a copy and assign once, so observers never see the
        // in-between state where the item is missing.
        var reordered = self.history
        let existingItem = reordered.remove(at: existingIndex)
        self.deleteStores(forDiscarded: taggedItem, keptId: existingItem.id)
        let updatedItem = ClipboardItem(
          id: existingItem.id,
          content: existingItem.content,
          timestamp: Date(),
          type: existingItem.type,
          imageData: existingItem.imageData,
          hasImage: existingItem.hasImage,
          imageHash: existingItem.imageHash,
          fileURLs: existingItem.fileURLs,
          sourceApp: existingItem.sourceApp,
          linkMetadata: existingItem.linkMetadata,
          hasRTF: existingItem.hasRTF,
          detectedTags: existingItem.detectedTags
        )
        reordered.insert(updatedItem, at: 0)
        self.history = reordered
        self.captured.send(updatedItem)
      } else {
        // New item - insert at beginning
        self.history.insert(taggedItem, at: 0)
        self.knownIdentifiers.insert(identifier)

        // If it's a URL, fetch link metadata (if enabled)
        if taggedItem.type == .url && self.settings.detectLinks {
          self.fetchLinkMetadata(for: taggedItem)
        }

        // Limit history size (0 = unlimited)
        self.trimHistory(to: self.settings.maxHistorySize)
        self.captured.send(taggedItem)
      }
    }
  }

  /// Remove a not-inserted duplicate's on-disk files. Capture eagerly writes
  /// image/RTF bytes to disk under a fresh UUID before dedup runs; when the
  /// incoming item is discarded in favor of an existing one, those files
  /// would otherwise be orphaned until the next launch's cleanup pass.
  private func deleteStores(forDiscarded item: ClipboardItem, keptId: UUID) {
    guard item.id != keptId else { return }
    if item.hasImage { ImageStore.shared.delete(for: item.id) }
    if item.hasRTF   { RTFStore.shared.delete(for: item.id) }
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
      let current = self.history.first(where: { $0.id == item.id }) ?? item
      self.history.removeAll { $0.id == item.id }
      let updatedItem = ClipboardItem(
        id: current.id,
        content: current.content,
        timestamp: Date(),
        type: current.type,
        imageData: current.imageData,
        hasImage: current.hasImage,
        imageHash: current.imageHash,
        fileURLs: current.fileURLs,
        sourceApp: current.sourceApp,
        linkMetadata: current.linkMetadata,
        hasRTF: current.hasRTF,
        detectedTags: current.detectedTags
      )
      self.history.insert(updatedItem, at: 0)
    }
  }

  /// Put an item on the pasteboard.
  /// - Parameter moveToFront: also mark it most-recently-used in history. The
  ///   paste stack passes false: reloading its queue head is not a "use" and
  ///   must not reshuffle history.
  func copyToClipboard(_ item: ClipboardItem, moveToFront: Bool = true) {
    pasteboard.clearContents()

    switch item.type {
    case .image:
      if let urls = item.fileURLs, !urls.isEmpty,
        urls.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) })
      {
        // Copied as an image file (e.g. in Finder): paste it back as that
        // file, so Finder accepts it and other apps get it with its name.
        pasteboard.writeObjects(urls as [NSURL])
      } else if let data = ImageStore.shared.loadData(for: item.id) ?? item.imageData,
        Self.writeImage(data, to: pasteboard)
      {
        // Written as compressed image data (see writeImage)
      } else if let image = item.nsImage {
        pasteboard.writeObjects([image])
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
      // If item has rich text formatting, include RTF data (loaded from disk on demand)
      if let rtfData = item.rtfData {
        pasteboard.setData(rtfData, forType: .rtf)
      }
      // Always include plain text as fallback
      pasteboard.setString(item.content, forType: .string)
    }

    changeCount = pasteboard.changeCount

    guard moveToFront else { return }

    // Move item to the front of the list (most recently used)
    DispatchQueue.main.async {
      // Read latest version from history to preserve async updates (e.g. link metadata)
      let current = self.history.first(where: { $0.id == item.id }) ?? item
      // Reorder a copy and publish once. Removing and inserting on `history`
      // directly published a state with the item missing, which observers
      // mistook for a different item arriving at the front.
      var reordered = self.history
      reordered.removeAll { $0.id == item.id }

      // Create a new item with updated timestamp and insert at front
      let updatedItem = ClipboardItem(
        id: current.id,
        content: current.content,
        timestamp: Date(),
        type: current.type,
        imageData: current.imageData,
        hasImage: current.hasImage,
        imageHash: current.imageHash,
        fileURLs: current.fileURLs,
        sourceApp: current.sourceApp,
        linkMetadata: current.linkMetadata,
        hasRTF: current.hasRTF,
        detectedTags: current.detectedTags
      )
      reordered.insert(updatedItem, at: 0)
      self.history = reordered
    }
  }

  func copyToClipboardAsPlainText(_ item: ClipboardItem) {
    pasteboard.clearContents()
    pasteboard.setString(item.content, forType: .string)
    changeCount = pasteboard.changeCount
  }

  /// Sync internal change count with the pasteboard so the polling timer
  /// does not re-process a pasteboard write we already handled externally.
  func syncPasteboardChangeCount() {
    changeCount = pasteboard.changeCount
  }

  func deleteItem(_ item: ClipboardItem) {
    DispatchQueue.main.async {
      // Find the index before removing
      if let index = self.history.firstIndex(where: { $0.id == item.id }) {
        // Store for undo
        let record = DeletedItemRecord(item: item, index: index, timestamp: Date())
        self.deletedItems.append(record)

        // Remove from history and dedup set
        self.history.remove(at: index)
        self.knownIdentifiers.remove(item.uniqueIdentifier)

        // Start undo cleanup timer if not already running
        if self.undoCleanupTimer == nil {
          self.startUndoCleanupTimer()
        }
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
        self.knownIdentifiers.insert(lastDeleted.item.uniqueIdentifier)
      }
    }
  }

  /// Image dimensions string ("W×H") read from compressed data headers via
  /// CGImageSource — no full bitmap decode.
  private static func imageDescription(from data: Data) -> String {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = props[kCGImagePropertyPixelWidth] as? Int,
      let height = props[kCGImagePropertyPixelHeight] as? Int
    else { return "Image" }
    return "\(width)×\(height)"
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
      if let scheme = url.scheme, !scheme.isEmpty {
        // Has an explicit scheme (http://..., ftp://..., etc.) — validate host
        if let validatedURL = URL(string: trimmed), validatedURL.host != nil {
          return true
        }
      } else {
        // Schemeless: must look like a real domain (e.g. "google.com")
        // Reject dot-prefixed strings (.hidden-file), dot-only strings, trailing dots
        let domainPattern = #"^[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])?)+(/.*)?$"#
        if trimmed.range(of: domainPattern, options: .regularExpression) != nil,
          let validatedURL = URL(string: "https://\(trimmed)"), validatedURL.host != nil
        {
          return true
        }
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

        // A plain-text edit invalidates any stored rich text — keeping the
        // old RTF would paste the pre-edit content into RTF-aware apps.
        if existingItem.hasRTF {
          RTFStore.shared.delete(for: existingItem.id)
        }

        let updatedItem = ClipboardItem(
          id: existingItem.id,
          content: trimmedContent,
          timestamp: existingItem.timestamp,
          type: newType,
          imageData: existingItem.imageData,
          hasImage: existingItem.hasImage,
          imageHash: existingItem.imageHash,
          fileURLs: existingItem.fileURLs,
          sourceApp: existingItem.sourceApp,
          linkMetadata: newMetadata,
          hasRTF: false,
          detectedTags: newTags
        )
        self.history[index] = updatedItem
        // Keep the dedup set in step with the edit, or a later copy of the
        // new text would add a second card instead of surfacing this one.
        self.knownIdentifiers.remove(existingItem.uniqueIdentifier)
        self.knownIdentifiers.insert(updatedItem.uniqueIdentifier)

        // If it became a URL or URL changed, fetch new metadata
        if newType == .url && (existingItem.type != .url || existingItem.content != trimmedContent)
        {
          self.fetchLinkMetadata(for: updatedItem)
        }
      }
    }
  }

  /// Whether the editor's text carries formatting the user would expect to
  /// keep: anything beyond the editor's own defaults (13pt system font in the
  /// default label colour).
  static func hasMeaningfulFormatting(_ string: NSAttributedString) -> Bool {
    var styled = false
    let defaultFamily = NSFont.systemFont(ofSize: 13).familyName
    string.enumerateAttributes(in: NSRange(location: 0, length: string.length)) { attrs, _, stop in
      if let font = attrs[.font] as? NSFont {
        let traits = NSFontManager.shared.traits(of: font)
        if traits.contains(.boldFontMask) || traits.contains(.italicFontMask)
          || abs(font.pointSize - 13) > 0.01 || font.familyName != defaultFamily
        {
          styled = true
        }
      }
      if (attrs[.underlineStyle] as? Int ?? 0) != 0 || (attrs[.strikethroughStyle] as? Int ?? 0) != 0 {
        styled = true
      }
      if attrs[.link] != nil || attrs[.backgroundColor] != nil || attrs[.superscript] != nil {
        styled = true
      }
      if let color = attrs[.foregroundColor] as? NSColor, !isDefaultTextColor(color) {
        styled = true
      }
      if let paragraph = attrs[.paragraphStyle] as? NSParagraphStyle,
        !paragraph.textLists.isEmpty
          || (paragraph.alignment != .natural && paragraph.alignment != .left)
      {
        styled = true
      }
      if styled { stop.pointee = true }
    }
    return styled
  }

  private static func isDefaultTextColor(_ color: NSColor) -> Bool {
    color == .labelColor || color == .textColor || color == .controlTextColor
  }

  /// RTF for storage and pasting, without the editor's default text colour.
  /// That colour is dynamic; written into RTF from dark mode it is frozen as
  /// white, which then pastes as invisible text into a light document.
  static func rtfData(from string: NSAttributedString) -> Data? {
    let cleaned = NSMutableAttributedString(attributedString: string)
    let full = NSRange(location: 0, length: cleaned.length)
    cleaned.enumerateAttribute(.foregroundColor, in: full) { value, range, _ in
      if let color = value as? NSColor, isDefaultTextColor(color) {
        cleaned.removeAttribute(.foregroundColor, range: range)
      }
    }
    return try? cleaned.data(
      from: full, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
  }

  func updateItemRichContent(_ item: ClipboardItem, attributedString: NSAttributedString) {
    // An edit with no formatting applied is a plain-text edit. Storing RTF
    // regardless made every edited clip paste as 13pt system-font rich text
    // from then on.
    guard Self.hasMeaningfulFormatting(attributedString) else {
      updateItemContent(item, newContent: attributedString.string)
      return
    }

    DispatchQueue.main.async {
      if let index = self.history.firstIndex(where: { $0.id == item.id }) {
        let existingItem = self.history[index]
        // Convert attributed string to RTF data and save directly to disk
        let rtfData = Self.rtfData(from: attributedString)
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
          hasImage: existingItem.hasImage,
          imageHash: existingItem.imageHash,
          fileURLs: existingItem.fileURLs,
          sourceApp: existingItem.sourceApp,
          linkMetadata: newMetadata,
          rtfData: rtfData,
          detectedTags: newTags
        )
        self.history[index] = updatedItem
        self.knownIdentifiers.remove(existingItem.uniqueIdentifier)
        self.knownIdentifiers.insert(updatedItem.uniqueIdentifier)

        // If it became a URL or URL changed, fetch new metadata
        if newType == .url && (existingItem.type != .url || existingItem.content != plainText) {
          self.fetchLinkMetadata(for: updatedItem)
        }
      }
    }
  }

  // MARK: - Images on the pasteboard

  /// Put an image on a pasteboard as compressed data (PNG, or JPEG if that is
  /// what we hold).
  ///
  /// Handing the pasteboard an `NSImage` makes AppKit write an *uncompressed*
  /// TIFF: four bytes per pixel, so a modest 928x1946 screenshot became a
  /// 7.2 MB TIFF in whatever app it was pasted into. The same image as PNG is
  /// a few hundred kilobytes at most. Apps that only understand TIFF lose
  /// nothing: macOS converts on request when PNG or JPEG is on the pasteboard.
  /// - Returns: false if the data is not an image we can write.
  @discardableResult
  static func writeImage(_ data: Data, to pasteboard: NSPasteboard) -> Bool {
    guard let representation = compactImageRepresentation(of: data) else { return false }
    return pasteboard.setData(representation.data, forType: representation.type)
  }

  /// The bytes and type to offer for an image: PNG and JPEG pass through
  /// untouched; anything else (TIFF from older history, HEIC, ...) is
  /// re-encoded as PNG at the same pixel size and resolution.
  static func compactImageRepresentation(of data: Data) -> (data: Data, type: NSPasteboard.PasteboardType)? {
    if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return (data, .png) }
    if data.starts(with: [0xFF, 0xD8, 0xFF]) { return (data, NSPasteboard.PasteboardType("public.jpeg")) }

    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    // Keep the resolution, so a Retina capture still pastes at its point size
    if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let dpi = properties[kCGImagePropertyDPIWidth] as? Double, dpi > 0
    {
      rep.size = NSSize(
        width: Double(cgImage.width) * 72 / dpi, height: Double(cgImage.height) * 72 / dpi)
    }
    guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
    return (png, .png)
  }

  // MARK: - Sync

  /// Insert or replace an item that arrived from iCloud, keeping history in
  /// most-recently-used order. Does not count as a copy the user made.
  func applyRemote(_ item: ClipboardItem) {
    var updated = history
    if let index = updated.firstIndex(where: { $0.id == item.id }) {
      knownIdentifiers.remove(updated[index].uniqueIdentifier)
      updated.remove(at: index)
    }
    let position = updated.firstIndex(where: { $0.timestamp < item.timestamp }) ?? updated.count
    updated.insert(item, at: position)
    knownIdentifiers.insert(item.uniqueIdentifier)
    history = updated
  }

  /// Remove items deleted on another device. No undo window: the deletion
  /// already happened elsewhere.
  func applyRemoteDelete(_ ids: Set<UUID>) {
    guard !ids.isEmpty else { return }
    let removed = history.filter { ids.contains($0.id) }
    guard !removed.isEmpty else { return }
    for item in removed {
      knownIdentifiers.remove(item.uniqueIdentifier)
      if item.hasImage { ImageStore.shared.delete(for: item.id) }
      if item.hasRTF { RTFStore.shared.delete(for: item.id) }
    }
    history.removeAll { ids.contains($0.id) }
  }

  // MARK: - Import

  /// Merge imported items into history without touching what is already
  /// there. An imported clip that duplicates an existing one (same ID, or the
  /// same content) is skipped.
  /// - Returns: how many were added, and for skipped duplicates a map from the
  ///   imported ID to the existing clip's ID, so pins can follow the clip.
  func mergeImported(_ items: [ClipboardItem]) -> (added: Int, idMap: [UUID: UUID]) {
    var merged = history
    var ids = Set(merged.map(\.id))
    var idMap: [UUID: UUID] = [:]
    var added = 0

    for item in items {
      if ids.contains(item.id) { continue }
      if knownIdentifiers.contains(item.uniqueIdentifier) {
        if let existing = merged.first(where: { $0.uniqueIdentifier == item.uniqueIdentifier }) {
          idMap[item.id] = existing.id
        }
        // The duplicate's own files were restored for nothing; drop them
        if item.hasImage { ImageStore.shared.delete(for: item.id) }
        if item.hasRTF { RTFStore.shared.delete(for: item.id) }
        continue
      }
      merged.append(item)
      ids.insert(item.id)
      knownIdentifiers.insert(item.uniqueIdentifier)
      added += 1
    }

    if added > 0 {
      merged.sort { $0.timestamp > $1.timestamp }
      history = merged
    }
    return (added, idMap)
  }

  /// Clear the clipboard history. Items pinned to a pinboard are kept: pins
  /// only reference history items, so removing those silently emptied every
  /// pinboard. Pass `includingPinned` to erase everything (full reset).
  func clearHistory(includingPinned: Bool = false) {
    DispatchQueue.main.async {
      self.performClear(includingPinned: includingPinned)
    }
  }

  /// Synchronous variant for app termination, where a queued block would never run.
  func clearHistoryNow(includingPinned: Bool = false) {
    performClear(includingPinned: includingPinned)
    if !history.isEmpty {
      historyStore.saveImmediately(items: history)
    }
  }

  private func performClear(includingPinned: Bool) {
    let kept = includingPinned ? [] : history.filter { isItemProtected?($0.id) == true }
    let removedPending = deletedItems.map(\.item)
    let removed = history.filter { item in !kept.contains(where: { $0.id == item.id }) } + removedPending

    history = kept
    knownIdentifiers = Set(kept.map(\.uniqueIdentifier))
    // Drop pending undos — their backing image/RTF files are removed below,
    // so restoring one would produce a permanently broken card.
    deletedItems.removeAll()
    undoCleanupTimer?.invalidate()
    undoCleanupTimer = nil

    if kept.isEmpty {
      // Nothing left: wipe the stores outright so nothing lingers on disk
      historyStore.deleteHistoryFile()
      ImageStore.shared.deleteAll()
      LinkImageStore.shared.deleteAll()
      RTFStore.shared.deleteAll()
    } else {
      for item in removed {
        if item.hasImage { ImageStore.shared.delete(for: item.id) }
        if item.hasRTF { RTFStore.shared.delete(for: item.id) }
      }
      if !kept.contains(where: { $0.type == .url }) {
        LinkImageStore.shared.deleteAll()
      }
    }
    onItemsPurged?(removed.map(\.id))
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
      "Press Return to paste the selected card into the app you were using. Shift+Return pastes it as plain text.",
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
      knownIdentifiers.insert(item.uniqueIdentifier)
      // First element = rightmost card = the one to pin
      if index == 0 {
        pinCardId = item.id
      }
    }
    return pinCardId
  }
}
