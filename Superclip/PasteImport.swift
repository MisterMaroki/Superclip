//
//  PasteImport.swift
//  Superclip
//
//  Brings clipboard history and pinboards over from Paste (pasteapp.io).
//
//  Paste keeps everything in a Core Data SQLite database inside its data
//  folder. Each item stores the original pasteboard contents as a list of
//  {type: data} dictionaries, serialised as a property list or JSON and
//  sometimes compressed (LZFSE or zlib). Large blobs live as separate files
//  next to the database.
//
//  The import never modifies Paste's files (it works on a copy of the
//  database) and only ever adds to Superclip: nothing already here is changed
//  or removed.
//

import AppKit
import Foundation
import SQLite3

enum PasteImportError: LocalizedError {
  case notPasteFolder
  case unsupportedVersion
  case unreadable(String)

  var errorDescription: String? {
    switch self {
    case .notPasteFolder:
      return "That folder doesn\u{2019}t contain Paste\u{2019}s data (no db.sqlite). Choose the folder named com.wiheads.paste or com.wiheads.paste-setapp."
    case .unsupportedVersion:
      return "This version of Paste stores its data in a way Superclip can\u{2019}t read yet."
    case .unreadable(let reason):
      return "Paste\u{2019}s data couldn\u{2019}t be read: \(reason)"
    }
  }
}

enum PasteImporter {

  // MARK: What was read from Paste (plain data, safe to build off the main thread)

  enum Kind {
    case text, link, image, files
  }

  struct Item {
    var id: UUID
    var kind: Kind
    /// The text, or the URL for a link.
    var text: String = ""
    var title: String?
    var imageData: Data?
    var fileURLs: [URL] = []
    var date: Date
    var appName: String?
    var bundleID: String?
    /// Database key of the pinboard it is on, if any.
    var listKey: Int?
    var order: Int = 0
  }

  struct List {
    var key: Int
    var name: String
    var color: PinboardColor
    var index: Int
  }

  struct Library {
    var items: [Item] = []
    var lists: [List] = []
    /// Items Paste had that carry nothing Superclip can show.
    var skipped = 0
  }

  struct Summary {
    let clips: Int
    let alreadyHere: Int
    let pinboards: Int
    let pins: Int
    let skipped: Int

    var description: String {
      func count(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }
      var parts = [clips == 0 && pins == 0 ? "Nothing new in Paste." : "Imported \(count(clips, "clip")) from Paste."]
      if pinboards > 0 || pins > 0 {
        parts.append("\(count(pins, "pin")) on \(count(pinboards, "new pinboard")).")
      }
      if alreadyHere > 0 {
        parts.append("\(count(alreadyHere, "clip")) \(alreadyHere == 1 ? "was" : "were") already in Superclip.")
      }
      if skipped > 0 { parts.append("\(count(skipped, "item")) had nothing to import.") }
      return parts.joined(separator: " ")
    }
  }

  // MARK: Finding Paste's data

  /// Where Paste keeps its data, for the versions we know of. Uses the real
  /// home directory: inside the sandbox `~` points at Superclip's container.
  nonisolated static func likelyFolders() -> [URL] {
    let home: URL
    if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
      home = URL(fileURLWithPath: String(cString: dir), isDirectory: true)
    } else {
      home = FileManager.default.homeDirectoryForCurrentUser
    }
    let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
    return [
      support.appendingPathComponent("com.wiheads.paste-setapp", isDirectory: true),
      support.appendingPathComponent("com.wiheads.paste", isDirectory: true),
      home.appendingPathComponent(
        "Library/Containers/com.wiheads.paste/Data/Library/Application Support/com.wiheads.paste", isDirectory: true),
    ]
  }

  // MARK: Reading

  /// Read everything importable from a Paste data folder.
  nonisolated static func read(folder: URL) throws -> Library {
    let source = folder.appendingPathComponent("db.sqlite")
    guard FileManager.default.fileExists(atPath: source.path) else { throw PasteImportError.notPasteFolder }

    // Work on a copy, including the write-ahead log, so Paste's own files are
    // never opened for writing and a running Paste is not disturbed.
    let work = FileManager.default.temporaryDirectory
      .appendingPathComponent("superclip-paste-import-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: work) }
    for suffix in ["", "-wal", "-shm"] {
      let from = URL(fileURLWithPath: source.path + suffix)
      if FileManager.default.fileExists(atPath: from.path) {
        try FileManager.default.copyItem(at: from, to: work.appendingPathComponent("db.sqlite" + suffix))
      }
    }

    var db: OpaquePointer?
    guard sqlite3_open_v2(work.appendingPathComponent("db.sqlite").path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
      let db
    else {
      throw PasteImportError.unreadable("the database would not open")
    }
    defer { sqlite3_close(db) }

    let externalDirectory = folder.appendingPathComponent(".db_SUPPORT/_EXTERNAL_DATA", isDirectory: true)
    var library = Library()

    let listRows = try rows(
      db,
      """
      select l.Z_PK, l.ZRAWTYPE, l.ZNAME, l.ZRAWATTRIBUTES, m.ZINDEX
      from ZLISTENTITY l left join ZLISTMETADATAENTITY m on m.ZLIST = l.Z_PK
      order by m.ZINDEX
      """)
    for (position, row) in listRows.enumerated() {
      // Type 2 is a pinboard; type 1 is the clipboard history itself
      guard let key = row[0] as? Int, row[1] as? Int == 2 else { continue }
      let name = (row[2] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let attributes = (row[3] as? Data).flatMap { resolve($0, externalDirectory: externalDirectory) }
        .flatMap { decode($0) as? [String: Any] }
      library.lists.append(
        List(
          key: key, name: name.isEmpty ? "Untitled" : name,
          color: pinboardColor(fromPasteAttributes: attributes, fallbackIndex: position),
          index: row[4] as? Int ?? position))
    }

    let itemRows = try rows(
      db,
      """
      select i.ZRAWTYPE, i.ZIDENTIFIER, i.ZTITLE, i.ZTIMESTAMP, i.ZCREATEDAT, i.ZLIST,
             i.ZDISPLAYORDERINPINBOARD, d.ZRAWPASTEBOARDITEMS, a.ZNAME, a.ZBUNDLEIDENTIFIER
      from ZITEMENTITY i
      left join ZITEMDATAENTITY d on d.Z_PK = i.ZDATA
      left join ZAPPLICATIONENTITY a on a.Z_PK = i.ZSOURCEAPPLICATION
      order by i.ZTIMESTAMP desc
      """)
    for row in itemRows {
      guard let blob = row[7] as? Data, let payload = resolve(blob, externalDirectory: externalDirectory),
        let contents = pasteboardContents(from: decode(payload))
      else {
        library.skipped += 1
        continue
      }
      let seconds = (row[3] as? Double) ?? (row[4] as? Double) ?? Date().timeIntervalSinceReferenceDate
      var item = Item(
        id: (row[1] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
        kind: .text,
        title: (row[2] as? String).flatMap { $0.isEmpty ? nil : $0 },
        date: Date(timeIntervalSinceReferenceDate: seconds),
        appName: row[8] as? String,
        bundleID: row[9] as? String,
        listKey: row[5] as? Int,
        order: row[6] as? Int ?? 0)
      if fill(&item, pasteType: row[0] as? Int ?? -1, from: contents) {
        library.items.append(item)
      } else {
        library.skipped += 1
      }
    }
    return library
  }

  /// Decide what an item is and pull out the part Superclip keeps.
  nonisolated private static func fill(_ item: inout Item, pasteType: Int, from contents: [String: Any]) -> Bool {
    func string(_ types: [String]) -> String? {
      for type in types {
        if let text = contents[type] as? String, !text.isEmpty { return text }
        if let data = contents[type] as? Data, let text = String(data: data, encoding: .utf8), !text.isEmpty {
          return text
        }
      }
      return nil
    }
    func data(_ types: [String]) -> Data? {
      for type in types {
        if let data = contents[type] as? Data, !data.isEmpty { return data }
        // In the JSON form binary values are base64 text
        if let text = contents[type] as? String, let data = Data(base64Encoded: text), !data.isEmpty { return data }
      }
      return nil
    }
    let plainText = string(["public.utf8-plain-text", "NSStringPboardType", "public.plain-text"])
    let imageTypes = ["public.png", "public.jpeg", "public.tiff", "public.heic", "com.compuserve.gif"]

    switch pasteType {
    case 1:  // image
      guard let image = data(imageTypes) else { return false }
      item.kind = .image
      item.imageData = image
      return true
    case 3:  // files
      let urls = fileURLs(in: contents)
      if !urls.isEmpty {
        item.kind = .files
        item.fileURLs = urls
        return true
      }
      if let image = data(imageTypes) {
        item.kind = .image
        item.imageData = image
        return true
      }
      return false
    case 4:  // link
      guard let url = string(["public.url"]) ?? plainText else { return false }
      item.kind = .link
      item.text = url.trimmingCharacters(in: .whitespacesAndNewlines)
      item.title = item.title ?? string(["public.url-name"])
      return true
    default:  // text, and anything unrecognised that still carries text
      guard let text = plainText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        if let image = data(imageTypes) {
          item.kind = .image
          item.imageData = image
          return true
        }
        return false
      }
      item.kind = .text
      item.text = text
      return true
    }
  }

  nonisolated private static func fileURLs(in contents: [String: Any]) -> [URL] {
    var texts: [String] = []
    if let several = contents["superclip.file-urls"] as? [String] {
      texts = several
    } else if let value = contents["public.file-url"] {
      if let text = (value as? String) ?? (value as? Data).flatMap({ String(data: $0, encoding: .utf8) }) {
        texts = [text]
      }
    }
    return texts.compactMap { text in
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
      guard let url = URL(string: trimmed), url.isFileURL else { return nil }
      return url
    }
  }

  // MARK: Paste's storage formats

  /// Core Data marks each blob that may live outside the database: 1 = the
  /// bytes follow, 2 = the name of a file in the external-data folder follows.
  nonisolated static func resolve(_ blob: Data, externalDirectory: URL) -> Data? {
    guard let marker = blob.first else { return nil }
    switch marker {
    case 1:
      return blob.dropFirst()
    case 2:
      let name = String(decoding: blob.dropFirst().prefix(while: { $0 != 0 }), as: UTF8.self)
      guard !name.isEmpty, !name.contains("/") else { return nil }
      return try? Data(contentsOf: externalDirectory.appendingPathComponent(name))
    default:
      return blob
    }
  }

  /// A payload is a property list or JSON, stored as is or compressed with
  /// LZFSE or zlib depending on the Paste version that wrote it.
  nonisolated static func decode(_ data: Data) -> Any? {
    if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) { return plist }
    if let json = try? JSONSerialization.jsonObject(with: data) { return json }
    for algorithm in [NSData.CompressionAlgorithm.lzfse, .zlib] {
      guard let inflated = try? (data as NSData).decompressed(using: algorithm) as Data, !inflated.isEmpty
      else { continue }
      if let plist = try? PropertyListSerialization.propertyList(from: inflated, format: nil) { return plist }
      if let json = try? JSONSerialization.jsonObject(with: inflated) { return json }
    }
    return nil
  }

  /// Flatten Paste's `[{dataByType: {type: value}, types: [...]}]` into one
  /// dictionary. File URLs can repeat (one pasteboard item per file), so
  /// those are kept under numbered keys by the caller's needs; here the first
  /// value for a type wins except for file URLs, which are all kept.
  nonisolated static func pasteboardContents(from decoded: Any?) -> [String: Any]? {
    guard let items = decoded as? [[String: Any]] else { return nil }
    var merged: [String: Any] = [:]
    var fileURLs: [Any] = []
    for item in items {
      guard let byType = item["dataByType"] as? [String: Any] else { continue }
      for (type, value) in byType {
        if type == "public.file-url" { fileURLs.append(value) }
        if merged[type] == nil { merged[type] = value }
      }
    }
    // Multiple files: keep them all, joined as newline-separated URL text
    if fileURLs.count > 1 {
      let texts = fileURLs.compactMap { ($0 as? String) ?? ($0 as? Data).flatMap { String(data: $0, encoding: .utf8) } }
      merged["superclip.file-urls"] = texts
    }
    return merged.isEmpty ? nil : merged
  }

  /// Nearest of Superclip's eight pinboard colours to the one Paste stored.
  nonisolated static func pinboardColor(fromPasteAttributes attributes: [String: Any]?, fallbackIndex: Int)
    -> PinboardColor
  {
    let all = PinboardColor.allCases
    guard let code = (attributes?["colorCode"] as? NSNumber)?.uint32Value else {
      return all[fallbackIndex % all.count]
    }
    let r = Double((code >> 16) & 0xFF), g = Double((code >> 8) & 0xFF), b = Double(code & 0xFF)
    let reference: [(PinboardColor, Double, Double, Double)] = [
      (.red, 255, 59, 48), (.orange, 255, 149, 0), (.yellow, 255, 204, 0), (.green, 52, 199, 89),
      (.blue, 0, 122, 255), (.purple, 175, 82, 222), (.pink, 255, 45, 85), (.cyan, 50, 173, 230),
    ]
    return reference.min { lhs, rhs in
      let dl = pow(lhs.1 - r, 2) + pow(lhs.2 - g, 2) + pow(lhs.3 - b, 2)
      let dr = pow(rhs.1 - r, 2) + pow(rhs.2 - g, 2) + pow(rhs.3 - b, 2)
      return dl < dr
    }?.0 ?? .blue
  }

  // MARK: SQLite

  nonisolated private static func rows(_ db: OpaquePointer, _ sql: String) throws -> [[Any?]] {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      // Tables or columns we expect are missing: a Paste version we don't know
      throw PasteImportError.unsupportedVersion
    }
    defer { sqlite3_finalize(statement) }
    var result: [[Any?]] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      var row: [Any?] = []
      for column in 0..<sqlite3_column_count(statement) {
        switch sqlite3_column_type(statement, column) {
        case SQLITE_INTEGER:
          row.append(Int(sqlite3_column_int64(statement, column)))
        case SQLITE_FLOAT:
          row.append(sqlite3_column_double(statement, column))
        case SQLITE_TEXT:
          row.append(sqlite3_column_text(statement, column).map { String(cString: $0) })
        case SQLITE_BLOB:
          let count = Int(sqlite3_column_bytes(statement, column))
          if count > 0, let bytes = sqlite3_column_blob(statement, column) {
            row.append(Data(bytes: bytes, count: count))
          } else {
            row.append(Data())
          }
        default:
          row.append(nil)
        }
      }
      result.append(row)
    }
    return result
  }

  // MARK: Adding to Superclip

  /// Merge what was read into Superclip. Existing clips and pinboards are
  /// left as they are; a Paste pinboard whose name matches one here adds its
  /// pins to that board.
  static func merge(_ library: Library, clipboard: ClipboardManager, pinboards: PinboardManager) -> Summary {
    var clips: [ClipboardItem] = []
    for entry in library.items {
      let source: SourceApp? = entry.appName.map {
        SourceApp(bundleIdentifier: entry.bundleID, name: $0, icon: nil)
      }
      switch entry.kind {
      case .text:
        clips.append(
          ClipboardItem(
            id: entry.id, content: entry.text, timestamp: entry.date, type: .text, sourceApp: source,
            detectedTags: ContentDetector.detect(text: entry.text)))
      case .link:
        let link = URL(string: entry.text).flatMap { url in
          entry.title.map { LinkMetadata(title: $0, url: url) }
        }
        clips.append(
          ClipboardItem(
            id: entry.id, content: entry.text, timestamp: entry.date, type: .url, sourceApp: source,
            linkMetadata: link, detectedTags: ContentDetector.detect(text: entry.text)))
      case .image:
        guard let raw = entry.imageData,
          let compact = ClipboardManager.compactImageRepresentation(of: raw)?.data
        else { continue }
        var item = ClipboardItem(
          id: entry.id, content: ClipboardManager.imageDimensionsText(for: compact), timestamp: entry.date,
          type: .image, imageData: compact, sourceApp: source)
        ImageStore.shared.save(data: compact, for: item.id)
        item.imageData = nil
        clips.append(item)
      case .files:
        clips.append(
          ClipboardItem(
            id: entry.id, content: entry.fileURLs.map(\.lastPathComponent).joined(separator: ", "),
            timestamp: entry.date, type: .file, fileURLs: entry.fileURLs, sourceApp: source))
      }
    }

    let before = clipboard.history.count
    let merged = clipboard.mergeImported(clips)
    let present = Set(clipboard.history.map(\.id))

    var newBoards = 0
    var pins = 0
    for list in library.lists.sorted(by: { $0.index < $1.index }) {
      let members = library.items.filter { $0.listKey == list.key }.sorted { $0.order < $1.order }
      let ids = members.map { merged.idMap[$0.id] ?? $0.id }.filter(present.contains)
      guard !ids.isEmpty else { continue }
      let board: Pinboard
      if let existing = pinboards.pinboards.first(where: { $0.name.caseInsensitiveCompare(list.name) == .orderedSame }) {
        board = existing
      } else {
        board = pinboards.createPinboard(name: list.name, color: list.color)
        newBoards += 1
      }
      for id in ids {
        let alreadyPinned = pinboards.pinboards.first(where: { $0.id == board.id })?.itemIds.contains(id) ?? false
        if !alreadyPinned {
          pinboards.addItem(id, to: board)
          pins += 1
        }
      }
    }

    let added = clipboard.history.count - before
    // Don't leave a large import sitting in the debounced save
    if added > 0 { clipboard.saveHistoryImmediately() }
    return Summary(
      clips: added, alreadyHere: clips.count - added, pinboards: newBoards, pins: pins,
      skipped: library.skipped)
  }
}
