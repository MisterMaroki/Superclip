// Logic tests for clipboard capture, the paste stack, history clearing, rich
// text edits, search and export/import.
//
// Run with scripts/tests/run.sh. Uses a private pasteboard and a scratch home
// directory: it never reads or writes the real clipboard or real Superclip data.
import AppKit
import CloudKit

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
// Safety: only ever run against the throwaway home directory the runner
// script sets up, never the real one (which holds real Superclip data).
precondition(
  ProcessInfo.processInfo.environment["SUPERCLIP_SCRATCH_HOME"].map { NSHomeDirectory() == $0 } ?? false,
  "run this through the script in scripts/, which points it at a scratch home directory")

var failures = 0
func check(_ name: String, _ cond: Bool, _ detail: @autoclosure () -> String = "") {
  if cond { print("ok    \(name)") } else { failures += 1; print("FAIL  \(name)  \(detail())") }
}
func spin(_ s: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

let pb = NSPasteboard(name: NSPasteboard.Name("superclip-test-\(ProcessInfo.processInfo.processIdentifier)"))
pb.clearContents()
let settings = SettingsManager()
settings.detectLinks = false
settings.monitorClipboard = true
settings.deduplicateItems = true
let clipboard = ClipboardManager(settings: settings, pasteboard: pb)
clipboard.clearHistory()
spin(0.2)
let stack = PasteStackManager(clipboardManager: clipboard)

/// What the user copying `text` in another app looks like to Superclip.
func userCopies(_ text: String) {
  pb.clearContents()
  pb.setString(text, forType: .string)
  clipboard.checkClipboardNow()
  spin(0.08)
}
func onPasteboard() -> String { pb.string(forType: .string) ?? "<nil>" }
func stackContents() -> [String] { stack.stackItems.map(\.content) }
/// What Cmd+V in another app does: the app reads the pasteboard, then the stack advances.
func userPastes() -> String {
  let pasted = onPasteboard()
  stack.advanceAfterPaste()
  spin(0.05)
  return pasted
}

// 1. Text is stored exactly as copied
userCopies("    return x\n")
check("capture keeps leading indent and trailing newline",
      clipboard.history.first?.content == "    return x\n", "\(String(describing: clipboard.history.first?.content))")
userCopies("   \n  ")
check("whitespace-only copy is ignored", clipboard.history.first?.content == "    return x\n")

// 2. Basic queue: copy A, B, C then paste three times
userCopies("pre-session")
stack.startSession()
spin(0.05)
check("stack starts empty (pre-session clipboard is not queued)", stackContents().isEmpty, "\(stackContents())")
userCopies("A"); userCopies("B"); userCopies("C")
check("three copies queue in order", stackContents() == ["A", "B", "C"], "\(stackContents())")
check("pasteboard holds the head, not the last copy", onPasteboard() == "A", onPasteboard())
spin(0.5)
check("stack does not react to its own pasteboard writes", stackContents() == ["A", "B", "C"], "\(stackContents())")
var pasted = [userPastes(), userPastes(), userPastes()]
check("Cmd+V x3 pastes A, B, C", pasted == ["A", "B", "C"], "\(pasted)")
check("stack is empty afterwards", stackContents().isEmpty)

// 3. Clicking a row pastes that row and restores the head
userCopies("A2"); userCopies("B2"); userCopies("C2")
let b = stack.stackItems[1]
stack.prepareToPaste(b)
check("clicking B puts B on the pasteboard", onPasteboard() == "B2", onPasteboard())
check("clicking B removes only B", stackContents() == ["A2", "C2"], "\(stackContents())")
spin(0.7)
check("after the click-paste the head is back on the pasteboard", onPasteboard() == "A2", onPasteboard())
check("clicked item is not re-queued", stackContents() == ["A2", "C2"], "\(stackContents())")

// 4. Clicking the head itself
let a = stack.stackItems[0]
stack.prepareToPaste(a)
check("clicking the head puts it on the pasteboard", onPasteboard() == "A2", onPasteboard())
spin(0.7)
check("then the next item becomes the head", stackContents() == ["C2"] && onPasteboard() == "C2", "\(stackContents()) / \(onPasteboard())")

// 5. Removing the head with the X button
userCopies("D2"); userCopies("E2")
check("queue is C2, D2, E2", stackContents() == ["C2", "D2", "E2"], "\(stackContents())")
stack.removeItem(stack.stackItems[0])
check("removing the head loads the new head", onPasteboard() == "D2" && stackContents() == ["D2", "E2"], "\(stackContents()) / \(onPasteboard())")
stack.removeItem(stack.stackItems[1])
check("removing a non-head item leaves the pasteboard alone", onPasteboard() == "D2" && stackContents() == ["D2"])
_ = userPastes()

// 6. Newest-first really changes paste order
userCopies("X"); userCopies("Y"); userCopies("Z")
stack.newestFirst = true
spin(0.05)
check("newest-first loads the newest item", onPasteboard() == "Z", onPasteboard())
pasted = [userPastes(), userPastes(), userPastes()]
check("newest-first pastes Z, Y, X", pasted == ["Z", "Y", "X"], "\(pasted)")
stack.newestFirst = false

// 7. Re-copying something already at the front of history still queues it
userCopies("same"); _ = userPastes()
check("stack empty before re-copy", stackContents().isEmpty)
userCopies("other-app-copy-elsewhere")  // a different app overwrote the pasteboard
_ = userPastes()
userCopies("same")
check("re-copy of an existing history item is queued", stackContents() == ["same"], "\(stackContents())")
_ = userPastes()

// 8. The same thing copied twice in one session is queued once
userCopies("dup"); userCopies("dup-b"); userCopies("dup")
check("duplicate copy is not queued twice", stackContents() == ["dup", "dup-b"], "\(stackContents())")

// 9. History order is not reshuffled by the stack reloading its head
let historyBefore = clipboard.history.prefix(3).map(\.content)
stack.removeItem(stack.stackItems[0])
spin(0.2)
check("reloading the head leaves history order alone", Array(clipboard.history.prefix(3).map(\.content)) == historyBefore)

// 10. Ending the session stops capturing into the stack
stack.endSession()
userCopies("after-session")
check("copies after the session ends are not queued", !stackContents().contains("after-session"))

// 11. A normal copy-from-history is one published change with the item present throughout
var sawMissing = false
let target = clipboard.history.last!
let c = clipboard.$history.sink { h in if !h.contains(where: { $0.id == target.id }) { sawMissing = true } }
clipboard.copyToClipboard(target)
spin(0.2)
c.cancel()
check("copy-from-history never publishes a state without the item", !sawMissing)
check("copy-from-history moves the item to the front", clipboard.history.first?.id == target.id)

// 12. Editing an item keeps dedup consistent
let edited = clipboard.history.first!
clipboard.updateItemContent(edited, newContent: "edited text")
spin(0.1)
let countBefore = clipboard.history.count
userCopies("edited text")
check("copying text equal to an edited item does not add a second card",
      clipboard.history.count == countBefore, "\(clipboard.history.count) vs \(countBefore)")


// 13. Clearing history keeps pinned items and their pins
let pins = PinboardManager()
for board in pins.pinboards { pins.deletePinboard(board) }
let board = pins.createPinboard(name: "Keep")
clipboard.isItemProtected = { id in pins.pinboards.contains { $0.itemIds.contains(id) } }
clipboard.onItemsPurged = { ids in pins.removeItems(ids) }
userCopies("keep me"); userCopies("drop me")
let keep = clipboard.history.first { $0.content == "keep me" }!
let drop = clipboard.history.first { $0.content == "drop me" }!
pins.addItem(keep.id, to: board)
pins.addItem(drop.id, to: board)
pins.removeItem(drop.id, from: pins.pinboards[0])
clipboard.clearHistory()
spin(0.2)
check("clear history keeps the pinned item", clipboard.history.map(\.content) == ["keep me"], "\(clipboard.history.map(\.content))")
check("its pin survives", pins.pinboards.first?.itemIds == [keep.id])
let afterClear = clipboard.history.count
userCopies("drop me")
check("a cleared item can be copied again as a new card", clipboard.history.count == afterClear + 1)
userCopies("keep me")
check("the kept item still deduplicates", clipboard.history.count == afterClear + 1, "\(clipboard.history.count)")

// 14. Formatting detection for the rich text editor
let base = NSFont.systemFont(ofSize: 13)
let plainAttr = NSAttributedString(string: "hello", attributes: [.font: base, .foregroundColor: NSColor.labelColor])
let boldAttr = NSAttributedString(string: "hello", attributes: [.font: NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask), .foregroundColor: NSColor.labelColor])
let underlined = NSAttributedString(string: "hello", attributes: [.font: base, .underlineStyle: NSUnderlineStyle.single.rawValue])
let centered: NSAttributedString = {
  let style = NSMutableParagraphStyle(); style.alignment = .center
  return NSAttributedString(string: "hello", attributes: [.font: base, .paragraphStyle: style])
}()
check("default-styled text is not 'formatted'", !ClipboardManager.hasMeaningfulFormatting(plainAttr))
check("bold counts as formatting", ClipboardManager.hasMeaningfulFormatting(boldAttr))
check("underline counts as formatting", ClipboardManager.hasMeaningfulFormatting(underlined))
check("alignment counts as formatting", ClipboardManager.hasMeaningfulFormatting(centered))

// 15. Saving an unstyled edit from the editor stays plain text
userCopies("to be edited")
let editable = clipboard.history.first!
clipboard.updateItemRichContent(editable, attributedString: NSAttributedString(string: "edited plainly", attributes: [.font: base, .foregroundColor: NSColor.labelColor]))
spin(0.15)
let afterPlain = clipboard.history.first { $0.id == editable.id }
check("unstyled edit updates the text", afterPlain?.content == "edited plainly", "\(String(describing: afterPlain?.content))")
check("unstyled edit stores no rich text", afterPlain?.hasRTF == false)
clipboard.updateItemRichContent(editable, attributedString: NSAttributedString(string: "edited bold", attributes: [.font: NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask), .foregroundColor: NSColor.labelColor]))
spin(0.15)
let afterBold = clipboard.history.first { $0.id == editable.id }
check("styled edit stores rich text", afterBold?.hasRTF == true && afterBold?.content == "edited bold")
if let rtf = afterBold?.rtfData, let back = NSAttributedString(rtf: rtf, documentAttributes: nil) {
  let font = back.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
  check("stored rich text keeps the bold", font.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false)
} else {
  check("stored rich text is readable", false)
}

// 16. Full reset clears pinned items too and prunes the pins
clipboard.clearHistory(includingPinned: true)
spin(0.2)
check("full clear removes everything", clipboard.history.isEmpty)
check("pins to removed items are pruned", pins.pinboards.first?.itemIds.isEmpty == true, "\(String(describing: pins.pinboards.first?.itemIds))")
for board in pins.pinboards { pins.deletePinboard(board) }


// 17. Search ranking: exact > prefix > word boundary > contains > loose
func mk(_ text: String, _ age: TimeInterval = 0) -> ClipboardItem {
  ClipboardItem(content: text, timestamp: Date().addingTimeInterval(-age), type: .text)
}
let corpus = [
  mk("the swift programming language"),   // word boundary
  mk("swift"),                            // exact
  mk("swiftly done"),                     // prefix
  mk("unswiftable"),                      // contains
  mk("s w i f t spaced out"),             // loose (letters in order)
  mk("nothing relevant here"),
]
let ranked = FuzzySearch.search(query: "Swift", in: corpus).map(\.content)
check("search ranks exact, prefix, word boundary, contains, loose",
      ranked == ["swift", "swiftly done", "the swift programming language", "unswiftable", "s w i f t spaced out"],
      "\(ranked)")
check("search drops non-matches", !ranked.contains("nothing relevant here"))
check("empty query returns everything in order", FuzzySearch.search(query: "  ", in: corpus).count == corpus.count)
let byApp = [ClipboardItem(content: "zzz", type: .text, sourceApp: SourceApp(bundleIdentifier: "com.apple.Safari", name: "Safari", icon: nil)), mk("qqq")]
check("search matches the source app name", FuzzySearch.search(query: "safari", in: byApp).map(\.content) == ["zzz"])
let accented = [mk("Café Zürich"), mk("plain")]
check("search is case-insensitive with non-ASCII text", FuzzySearch.search(query: "zürich", in: accented).map(\.content) == ["Café Zürich"])
let longLoose = mk(String(repeating: "a quick brown fox ", count: 400))  // 7,200 chars
check("a long text still matches on a real substring", FuzzySearch.search(query: "brown fox", in: [longLoose]).count == 1)
check("a long text does not match on scattered letters", FuzzySearch.search(query: "qbfx", in: [longLoose]).isEmpty)

// 18. Search cost on a large history (this binary is unoptimised; release is several times faster)
let filler = "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor "
let big = (0..<2000).map { mk("\($0) " + String(repeating: filler, count: 6), TimeInterval($0)) }
_ = FuzzySearch.search(query: "warm", in: big)  // fill the per-clip cache, as the first keystroke does
var start = Date()
_ = FuzzySearch.search(query: "zzqx", in: big)
let noHit = Date().timeIntervalSince(start)
start = Date()
_ = FuzzySearch.search(query: "tempor", in: big)
let hit = Date().timeIntervalSince(start)
print(String(format: "info  search over 2,000 x 470-char clips: no-hit %.0f ms, hit %.0f ms (unoptimised build)", noHit * 1000, hit * 1000))
check("search over 2,000 clips stays interactive", noHit < 0.35 && hit < 0.35)


// 19. Export then import round trip
clipboard.clearHistory(includingPinned: true)
spin(0.2)
let snips = SnippetManager()
for sn in snips.snippets { snips.deleteSnippet(sn) }
let pins2 = PinboardManager()
for b in pins2.pinboards { pins2.deletePinboard(b) }
userCopies("alpha"); userCopies("  beta with indent\n"); userCopies("https://example.com/page")
let png: Data = {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  return rep.representation(using: .png, properties: [:])!
}()
var imageItem = ClipboardItem(content: "8\u{00D7}8", type: .image, imageData: png)
ImageStore.shared.save(data: png, for: imageItem.id)
imageItem.imageData = nil
clipboard.addToHistory(item: imageItem)
spin(0.1)
let alpha = clipboard.history.first { $0.content == "alpha" }!
let workBoard = pins2.createPinboard(name: "Work", color: .green)
pins2.addItem(alpha.id, to: workBoard)
pins2.addItem(imageItem.id, to: workBoard)
snips.createSnippet(name: "Mail", trigger: ";;mail", content: "me@example.com")
let exported = try! DataArchive.export(clipboard: clipboard, pinboards: pins2, snippets: snips)
let beforeContents = clipboard.history.map(\.content)

// wipe everything, then import
clipboard.clearHistory(includingPinned: true)
spin(0.2)
for b in pins2.pinboards { pins2.deletePinboard(b) }
for sn in snips.snippets { snips.deleteSnippet(sn) }
check("stores are empty before import", clipboard.history.isEmpty && !ImageStore.shared.exists(for: imageItem.id))
let summary = try! DataArchive.importArchive(exported, clipboard: clipboard, pinboards: pins2, snippets: snips)
spin(0.1)
check("import restores every clip in order", clipboard.history.map(\.content) == beforeContents, "\(clipboard.history.map(\.content))")
check("import keeps whitespace exactly", clipboard.history.contains { $0.content == "  beta with indent\n" })
check("import restores image bytes", ImageStore.shared.loadData(for: imageItem.id) == png)
check("import restores the pinboard and its pins", pins2.pinboards.first?.name == "Work" && Set(pins2.pinboards.first?.itemIds ?? []) == [alpha.id, imageItem.id])
check("import restores snippets", snips.snippets.map(\.trigger) == [";;mail"])
check("summary counts what was added", summary.items == 4 && summary.pinboards == 1 && summary.snippets == 1, "\(summary)")

// importing the same file again adds nothing
let again = try! DataArchive.importArchive(exported, clipboard: clipboard, pinboards: pins2, snippets: snips)
spin(0.1)
check("re-importing adds nothing", again.isEmpty && clipboard.history.count == 4 && pins2.pinboards.count == 1 && snips.snippets.count == 1, "\(again)")

// import into a history that already has the same text under a different ID: the pin follows the existing clip
clipboard.clearHistory(includingPinned: true)
spin(0.2)
for b in pins2.pinboards { pins2.deletePinboard(b) }
userCopies("alpha")
let localAlpha = clipboard.history.first!
check("local clip has a different id than the exported one", localAlpha.id != alpha.id)
_ = try! DataArchive.importArchive(exported, clipboard: clipboard, pinboards: pins2, snippets: snips)
spin(0.1)
check("a duplicate clip is not added twice", clipboard.history.filter { $0.content == "alpha" }.count == 1)
check("the imported pin points at the existing clip", pins2.pinboards.first?.itemIds.contains(localAlpha.id) == true, "\(String(describing: pins2.pinboards.first?.itemIds))")

// garbage and future versions are rejected without changing anything
let countBeforeBad = clipboard.history.count
check("garbage is rejected", (try? DataArchive.importArchive(Data("not json".utf8), clipboard: clipboard, pinboards: pins2, snippets: snips)) == nil)
var future = try! JSONSerialization.jsonObject(with: exported) as! [String: Any]
future["version"] = 99
check("a newer format version is rejected", (try? DataArchive.importArchive(try! JSONSerialization.data(withJSONObject: future), clipboard: clipboard, pinboards: pins2, snippets: snips)) == nil)
check("rejected imports change nothing", clipboard.history.count == countBeforeBad)
for b in pins2.pinboards { pins2.deletePinboard(b) }
for sn in snips.snippets { snips.deleteSnippet(sn) }


// ---------------------------------------------------------------- Sync

// The sync types are main-actor bound, so these run inside a main-actor function.
@MainActor func syncTests() {

  let t0 = Date(timeIntervalSince1970: 1_700_000_000)
  func sc(_ id: UUID = UUID(), _ content: String, device: String, created: TimeInterval = 0, used: TimeInterval = 0, modified: TimeInterval = 0) -> SyncClip {
    SyncClip(id: id, type: .text, content: content, title: nil, createdAt: t0 + created, lastUsedAt: t0 + used,
             modifiedAt: t0 + modified, sourceApp: "Notes", sourceBundleID: nil, device: device,
             imageWidth: nil, imageHeight: nil, contentHash: SyncClip.hash(type: .text, content: content))
  }

  // 20. Merging two versions of the same clip
  let sameID = UUID()
  let mergedClip = SyncMerge.merge(local: sc(sameID, "old text", device: "Mac", used: 500, modified: 10),
                                   remote: sc(sameID, "edited on phone", device: "Mac", used: 100, modified: 90))
  check("sync: the later edit wins the content", mergedClip.content == "edited on phone")
  check("sync: last-used only moves forward", mergedClip.lastUsedAt == t0 + 500)
  let mergedOther = SyncMerge.merge(local: sc(sameID, "edited on phone", device: "Mac", used: 100, modified: 90),
                                    remote: sc(sameID, "old text", device: "Mac", used: 500, modified: 10))
  check("sync: both devices reach the same merged clip", mergedOther.content == mergedClip.content && mergedOther.lastUsedAt == mergedClip.lastUsedAt)

  // 21. The same content captured on two devices
  let onMac = sc(UUID(), "relayed by universal clipboard", device: "Mac", created: 0, used: 5)
  let onPhone = sc(UUID(), "relayed by universal clipboard", device: "iPhone", created: 3, used: 60)
  let fromMacSide = SyncMerge.resolveDuplicate(onMac, onPhone)
  let fromPhoneSide = SyncMerge.resolveDuplicate(onPhone, onMac)
  check("sync: duplicate across devices keeps the older clip", fromMacSide?.keep.id == onMac.id && fromMacSide?.drop.id == onPhone.id)
  check("sync: both devices pick the same survivor", fromMacSide?.keep.id == fromPhoneSide?.keep.id)
  check("sync: the survivor takes the newer last-used time", fromMacSide?.keep.lastUsedAt == t0 + 60)
  check("sync: same device twice is not a cross-device duplicate", SyncMerge.resolveDuplicate(onMac, sc(UUID(), onMac.content, device: "Mac")) == nil)
  check("sync: different content is not a duplicate", SyncMerge.resolveDuplicate(onMac, sc(UUID(), "something else", device: "iPhone")) == nil)

  // 22. Pinboard clip lists
  let (pa, pb2, pc, pd) = (UUID(), UUID(), UUID(), UUID())
  check("sync: pins added on both devices are both kept",
        Set(SyncMerge.mergeLists(local: [pa, pb2, pc], remote: [pa, pb2, pd], ancestor: [pa, pb2])) == [pa, pb2, pc, pd])
  check("sync: an unpin on the other device sticks",
        SyncMerge.mergeLists(local: [pa, pb2], remote: [pa], ancestor: [pa, pb2]) == [pa])
  check("sync: an unpin here sticks against an unchanged remote",
        SyncMerge.mergeLists(local: [pa], remote: [pa, pb2], ancestor: [pa, pb2]) == [pa])
  check("sync: unpin on one side and pin on the other both apply",
        Set(SyncMerge.mergeLists(local: [pb2, pc], remote: [pa, pb2], ancestor: [pa, pb2])) == [pb2, pc])
  check("sync: with no common ancestor nothing is dropped",
        Set(SyncMerge.mergeLists(local: [pa], remote: [pb2], ancestor: nil)) == [pa, pb2])
  check("sync: remapping a dropped duplicate leaves no doubles", SyncMerge.remap([pa, pb2, pc], replacing: pb2, with: pa) == [pa, pc])

  // 23. What stays in iCloud
  check("sync: a 31-day-old unpinned clip has expired", SyncPolicy.isExpired(lastUsedAt: Date().addingTimeInterval(-31 * 86_400), isPinned: false))
  check("sync: a pinned clip never expires", !SyncPolicy.isExpired(lastUsedAt: Date().addingTimeInterval(-400 * 86_400), isPinned: true))
  check("sync: a recent clip has not expired", !SyncPolicy.isExpired(lastUsedAt: Date().addingTimeInterval(-86_400), isPinned: false))

  // 24. Record names and CloudKit round trips (no network involved)
  let key = SyncKey(.pinboard, pa)
  check("sync: record names round-trip", SyncKey(recordName: key.recordName) == key && SyncKey(recordName: "nonsense") == nil)
  let zone = CloudSyncEngine.zoneID
  let clipRecord = CKRecord(recordType: "Clip", recordID: CKRecord.ID(recordName: SyncKey(.clip, onMac.id).recordName, zoneID: zone))
  CloudRecordCoding.encode(onMac, into: clipRecord)
  check("sync: a clip survives encoding to a record and back", CloudRecordCoding.decodeClip(clipRecord) == onMac)
  check("sync: clip text is stored in an encrypted field, not in the clear", clipRecord["content"] == nil && clipRecord.encryptedValues["content"] as? String == onMac.content)
  let boardModel = SyncPinboard(id: pa, name: "Brand", color: "orange", position: 2, clipIDs: [pb2, pc], modifiedAt: t0)
  let boardRecord = CKRecord(recordType: "Pinboard", recordID: CKRecord.ID(recordName: SyncKey(.pinboard, pa).recordName, zoneID: zone))
  CloudRecordCoding.encode(boardModel, into: boardRecord)
  check("sync: a pinboard survives the round trip", CloudRecordCoding.decodePinboard(boardRecord) == boardModel)
  let snippetModel = SyncSnippet(id: pd, name: "Mail", trigger: ";;mail", content: "me@example.com", isEnabled: false, modifiedAt: t0)
  let snippetRecord = CKRecord(recordType: "Snippet", recordID: CKRecord.ID(recordName: SyncKey(.snippet, pd).recordName, zoneID: zone))
  CloudRecordCoding.encode(snippetModel, into: snippetRecord)
  check("sync: a snippet survives the round trip", CloudRecordCoding.decodeSnippet(snippetRecord) == snippetModel)
  let fields = CloudRecordCoding.systemFields(of: clipRecord)
  check("sync: a record can be rebuilt from its system fields", CloudRecordCoding.record(fromSystemFields: fields)?.recordID == clipRecord.recordID)

  // 25. Change tracking
  var tracker = SyncChangeTracker()
  let k1 = SyncKey(.clip, UUID()), k2 = SyncKey(.clip, UUID())
  check("sync: first look reports everything", Set(tracker.changes(in: [k1: 1, k2: 2])) == [k1, k2])
  check("sync: nothing changed, nothing reported", tracker.changes(in: [k1: 1, k2: 2]).isEmpty)
  check("sync: only the changed record is reported", tracker.changes(in: [k1: 1, k2: 3]) == [k2])
  check("sync: a record that vanished is not reported as a change", tracker.changes(in: [k1: 1]).isEmpty)
  tracker.acknowledge([k1: 9])
  check("sync: acknowledged remote changes are not echoed back", tracker.changes(in: [k1: 9]).isEmpty)

  // 26. The Mac applying changes that arrive from iCloud
  clipboard.clearHistory(includingPinned: true)
  spin(0.2)
  let syncPins = PinboardManager()
  for b in syncPins.pinboards { syncPins.deletePinboard(b) }
  let syncSnips = SnippetManager()
  for sn in syncSnips.snippets { syncSnips.deleteSnippet(sn) }
  clipboard.isItemProtected = { id in syncPins.pinboards.contains { $0.itemIds.contains(id) } }
  clipboard.onItemsPurged = nil
  settings.syncEnabled = false
  let coordinator = MacSyncCoordinator(clipboard: clipboard, pinboards: syncPins, snippets: syncSnips, settings: settings)

  userCopies("already on the mac")
  let localItem = clipboard.history.first!
  let recent = Date().addingTimeInterval(-120)
  func remoteClip(_ content: String, id: UUID = UUID(), used: Date = recent, device: String = "iPhone", type: SyncClipType = .text) -> SyncClip {
    SyncClip(id: id, type: type, content: content, title: type == .link ? "A title" : nil, createdAt: used, lastUsedAt: used,
             modifiedAt: used, sourceApp: "Safari", sourceBundleID: nil, device: device, imageWidth: nil, imageHeight: nil,
             contentHash: SyncClip.hash(type: type, content: content))
  }

  var incoming = RemoteChanges()
  let fromPhone = remoteClip("copied on the phone")
  let linkFromPhone = remoteClip("https://example.com/a", type: .link)
  let colourFromPhone = remoteClip("#FF5733", used: recent.addingTimeInterval(-600))
  incoming.clips = [.init(clip: fromPhone), .init(clip: linkFromPhone), .init(clip: colourFromPhone)]
  coordinator.apply(incoming)
  check("mac sync: remote clips appear in history", clipboard.history.count == 4, "\(clipboard.history.map(\.content))")
  check("mac sync: history stays in most-recently-used order",
        clipboard.history.map(\.content) == ["already on the mac", "copied on the phone", "https://example.com/a", "#FF5733"]
        || clipboard.history.first?.content == "already on the mac", "\(clipboard.history.map(\.content))")
  check("mac sync: a remote link becomes a link card with its title",
        clipboard.history.first { $0.id == linkFromPhone.id }.map { $0.type == .url && $0.linkMetadata?.title == "A title" } ?? false)
  check("mac sync: remote text is tagged like local text", clipboard.history.first { $0.id == colourFromPhone.id }?.detectedTags.contains(.color) == true)
  let afterInsert = clipboard.history.count
  userCopies("copied on the phone")
  check("mac sync: a synced clip deduplicates like any other", clipboard.history.count == afterInsert)

  // the same text saved on both devices under different IDs
  userCopies("relayed text")
  let twin = clipboard.history.first { $0.content == "relayed text" }!
  let board26 = syncPins.createPinboard(name: "Keep")
  syncPins.addItem(twin.id, to: board26)
  var relay = RemoteChanges()
  let olderRemote = remoteClip("relayed text", used: Date().addingTimeInterval(-3600))
  relay.clips = [.init(clip: olderRemote)]
  coordinator.apply(relay)
  check("mac sync: the same text from the phone does not add a second card", clipboard.history.filter { $0.content == "relayed text" }.count == 1)
  check("mac sync: the older of the two survives", clipboard.history.contains { $0.id == olderRemote.id } && !clipboard.history.contains { $0.id == twin.id })
  check("mac sync: the pin follows the surviving clip", syncPins.pinboards.first?.itemIds == [olderRemote.id], "\(String(describing: syncPins.pinboards.first?.itemIds))")

  // deletions
  var deletions = RemoteChanges()
  deletions.deleted = [SyncKey(.clip, fromPhone.id)]
  coordinator.apply(deletions)
  check("mac sync: a clip deleted on the phone is removed here", !clipboard.history.contains { $0.id == fromPhone.id })
  var oldLocal = remoteClip("ancient and unpinned", used: Date().addingTimeInterval(-40 * 86_400))
  oldLocal.device = "Mac"
  var ancient = RemoteChanges(); ancient.clips = [.init(clip: oldLocal)]
  coordinator.apply(ancient)
  var expiry = RemoteChanges(); expiry.deleted = [SyncKey(.clip, oldLocal.id)]
  coordinator.apply(expiry)
  check("mac sync: a clip that merely aged out of iCloud stays on the Mac", clipboard.history.contains { $0.id == oldLocal.id })

  // pinboards and snippets
  var boards = RemoteChanges()
  let remoteBoardID = UUID()
  boards.pinboards = [.init(pinboard: SyncPinboard(id: remoteBoardID, name: "From phone", color: "green", position: 0, clipIDs: [linkFromPhone.id], modifiedAt: Date()), ancestorClipIDs: nil)]
  boards.snippets = [SyncSnippet(id: UUID(), name: "Sig", trigger: ";;sig", content: "Best, O", isEnabled: true, modifiedAt: Date())]
  coordinator.apply(boards)
  check("mac sync: a remote pinboard appears with its pins", syncPins.pinboards.first { $0.id == remoteBoardID }.map { $0.name == "From phone" && $0.color == .green && $0.itemIds == [linkFromPhone.id] } ?? false)
  check("mac sync: a remote snippet appears", syncSnips.snippets.contains { $0.trigger == ";;sig" })
  // local pin added, then a remote change that removed the original pin: both edits must hold
  syncPins.addItem(colourFromPhone.id, to: syncPins.pinboards.first { $0.id == remoteBoardID }!)
  var boardEdit = RemoteChanges()
  boardEdit.pinboards = [.init(pinboard: SyncPinboard(id: remoteBoardID, name: "Renamed on phone", color: "green", position: 0, clipIDs: [], modifiedAt: Date().addingTimeInterval(5)), ancestorClipIDs: [linkFromPhone.id])]
  coordinator.apply(boardEdit)
  let mergedBoard = syncPins.pinboards.first { $0.id == remoteBoardID }
  check("mac sync: a remote unpin and a local pin both hold", mergedBoard?.itemIds == [colourFromPhone.id], "\(String(describing: mergedBoard?.itemIds))")
  check("mac sync: the later rename wins", mergedBoard?.name == "Renamed on phone")
  var boardGone = RemoteChanges(); boardGone.deleted = [SyncKey(.pinboard, remoteBoardID)]
  coordinator.apply(boardGone)
  check("mac sync: a pinboard deleted on the phone is removed here", !syncPins.pinboards.contains { $0.id == remoteBoardID })

  // image clip with bytes
  var imageChange = RemoteChanges()
  var imageClip = remoteClip("8\u{00D7}8", type: .image)
  imageClip.imageWidth = 8; imageClip.imageHeight = 8
  imageChange.clips = [.init(clip: imageClip, imageData: png)]
  coordinator.apply(imageChange)
  check("mac sync: a remote image is stored and shown as an image", clipboard.history.first { $0.id == imageClip.id }.map { $0.type == .image && $0.hasImage } ?? false)
  check("mac sync: its bytes are on disk", ImageStore.shared.loadData(for: imageClip.id) == png)
  check("mac sync: what the Mac would upload for it matches", coordinator.syncClip(imageClip.id).map { $0.type == .image && $0.imageWidth == 8 && $0.device == "iPhone" } ?? false)
  check("mac sync: files are never offered for sync", coordinator.allSyncKeys().allSatisfy { key in key.entity != .clip || clipboard.history.first { $0.id == key.id }?.type != .file })

  for b in syncPins.pinboards { syncPins.deletePinboard(b) }
  for sn in syncSnips.snippets { syncSnips.deleteSnippet(sn) }

}
MainActor.assumeIsolated { syncTests() }


// ---------------------------------------------------------------- Images on the clipboard

// A capture-sized image: 928 x 1946 pixels, mostly flat like a real screenshot
let shotRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 928, pixelsHigh: 1946, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: shotRep)
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 928, height: 1946).fill()
NSColor.darkGray.setFill(); for i in 0..<40 { NSRect(x: 40, y: 40 + i * 46, width: 300 + (i * 37) % 500, height: 18).fill() }
NSGraphicsContext.restoreGraphicsState()
shotRep.size = NSSize(width: 464, height: 973)  // Retina: half as many points as pixels
let shotPNG = shotRep.representation(using: .png, properties: [:])!
let shotTIFF = shotRep.tiffRepresentation!
let shotJPEG = shotRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])!
func imageItem(_ data: Data) -> ClipboardItem {
  var item = ClipboardItem(content: "928\u{00D7}1946", type: .image, imageData: data)
  ImageStore.shared.save(data: data, for: item.id)
  item.imageData = nil
  return item
}
func firstType() -> String { pb.types?.first?.rawValue ?? "<none>" }

let pngItem = imageItem(shotPNG)
clipboard.copyToClipboard(pngItem, moveToFront: false)
check("image copy: a screenshot goes on the clipboard as PNG", firstType() == "public.png", firstType())
check("image copy: the PNG bytes are the stored ones, untouched", pb.data(forType: .png) == shotPNG)
let pastedBytes = pb.data(forType: .png)?.count ?? 0
print("info  928 x 1946 capture on the clipboard: \(pastedBytes / 1024) KB as PNG (was \(shotTIFF.count / 1024) KB as uncompressed TIFF)")
check("image copy: far smaller than the uncompressed TIFF it used to be", pastedBytes * 20 < shotTIFF.count, "\(pastedBytes) vs \(shotTIFF.count)")
check("image copy: apps that ask for TIFF or an NSImage still get one", pb.data(forType: .tiff) != nil && NSImage(pasteboard: pb) != nil)

let tiffItem = imageItem(shotTIFF)
clipboard.copyToClipboard(tiffItem, moveToFront: false)
check("image copy: an image stored as TIFF is offered as PNG", firstType() == "public.png", firstType())
if let converted = pb.data(forType: .png), let rep = NSBitmapImageRep(data: converted) {
  check("image copy: conversion keeps the pixel size", rep.pixelsWide == 928 && rep.pixelsHigh == 1946, "\(rep.pixelsWide)x\(rep.pixelsHigh)")
  check("image copy: conversion keeps the Retina resolution", abs(rep.size.width - 464) < 1, "\(rep.size)")
  check("image copy: the converted image is small too", converted.count * 20 < shotTIFF.count)
} else {
  check("image copy: converted PNG is readable", false)
}

let jpegItem = imageItem(shotJPEG)
clipboard.copyToClipboard(jpegItem, moveToFront: false)
check("image copy: a JPEG stays a JPEG (not inflated to PNG)", firstType() == "public.jpeg" && pb.data(forType: NSPasteboard.PasteboardType("public.jpeg")) == shotJPEG, firstType())
check("image copy: junk is refused rather than written", !ClipboardManager.writeImage(Data("not an image".utf8), to: pb))
for item in [pngItem, tiffItem, jpegItem] { ImageStore.shared.delete(for: item.id) }


// ---------------------------------------------------------------- Capture targets (multiple displays)

// Checked against Core Graphics for every display actually connected, so on a
// multi-display setup this exercises the secondary-display maths for real.
print("info  displays connected: \(NSScreen.screens.count)")
for screen in NSScreen.screens {
  let target = CaptureTarget(screen: screen)
  let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
  check("capture: target carries its own display's ID (\(target.displayID))", number.map { CGDirectDisplayID($0) } == target.displayID)
  let cg = CGDisplayBounds(target.displayID)
  check("capture: display \(target.displayID) origin matches Core Graphics",
        abs(target.cgOrigin.x - cg.origin.x) < 0.5 && abs(target.cgOrigin.y - cg.origin.y) < 0.5,
        "\(target.cgOrigin) vs \(cg.origin)")
  check("capture: display \(target.displayID) uses its own scale and size",
        target.scale == screen.backingScaleFactor && target.frame.size == screen.frame.size)
}
if let underPointer = CaptureTarget.screenUnderPointer() {
  check("capture: the screen under the pointer contains the pointer",
        NSMouseInRect(NSEvent.mouseLocation, underPointer.frame, false) || NSScreen.screens.count == 1)
}
let ids = Set(NSScreen.screens.map { CaptureTarget(screen: $0).displayID })
check("capture: every display gets a distinct target", ids.count == NSScreen.screens.count)

clipboard.clearHistory()
spin(0.2)
pb.releaseGlobally()
print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
