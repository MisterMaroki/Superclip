// Renders the app's main screens with sample data, in light and dark
// appearance, to PNG files. A quick way to look over every screen in both
// themes without driving the app by hand.
//
// Run with scripts/render-screens/run.sh. Uses a private pasteboard and a
// scratch home directory: it never reads the real clipboard or real Superclip data.
import AppKit
import SwiftUI

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let outDir = CommandLine.arguments[1]
let tag = CommandLine.arguments[2]
let only: Set<String>? =
  CommandLine.arguments.count > 3
  ? Set(CommandLine.arguments[3].split(separator: ",").map(String.init)) : nil

// Safety: only ever run against the throwaway home directory the runner
// script sets up, never the real one (which holds real Superclip data).
precondition(
  ProcessInfo.processInfo.environment["SUPERCLIP_SCRATCH_HOME"].map { NSHomeDirectory() == $0 } ?? false,
  "run this through the script in scripts/, which points it at a scratch home directory")

func spin(_ seconds: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

func makeImagePNG() -> Data {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 640, pixelsHigh: 400, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  NSGradient(starting: .systemTeal, ending: .systemIndigo)!.draw(
    in: NSRect(x: 0, y: 0, width: 640, height: 400), angle: 30)
  NSColor.white.setFill()
  NSRect(x: 60, y: 60, width: 300, height: 30).fill()
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

let settings = SettingsManager()
settings.detectLinks = false  // no network from the harness
let clipboard = ClipboardManager(settings: settings, pasteboard: NSPasteboard(name: NSPasteboard.Name("superclip-harness-\(ProcessInfo.processInfo.processIdentifier)")))
let pinboards = PinboardManager()
let snippets = SnippetManager()
let nav = NavigationState()
let stack = PasteStackManager(clipboardManager: clipboard)
spin(0.2)

func src(_ id: String, _ name: String) -> SourceApp {
  SourceApp(bundleIdentifier: id, name: name, icon: nil)
}

let imagePNG = makeImagePNG()
let seed: [ClipboardItem] = [
  ClipboardItem(
    content: "/Applications/Safari.app", type: .file,
    fileURLs: [URL(fileURLWithPath: "/Applications/Safari.app")],
    sourceApp: src("com.apple.finder", "Finder")),
  ClipboardItem(content: "+1 (415) 555-0132", sourceApp: src("com.apple.Notes", "Notes")),
  ClipboardItem(content: "hello@superclip.app", sourceApp: src("com.apple.mail", "Mail")),
  ClipboardItem(
    content: "{\"name\": \"Superclip\", \"version\": 1.1, \"tags\": [\"clipboard\", \"mac\"]}",
    sourceApp: src("com.microsoft.VSCode", "Code")),
  ClipboardItem(
    content:
      "func greet(_ name: String) -> String {\n    let greeting = \"Hello, \\(name)!\"\n    return greeting\n}",
    sourceApp: src("com.apple.dt.Xcode", "Xcode")),
  ClipboardItem(content: "rgb(20, 20, 24)", sourceApp: src("com.figma.Desktop", "Figma")),
  ClipboardItem(content: "#F4F1E8", sourceApp: src("com.figma.Desktop", "Figma")),
  ClipboardItem(content: "#FF5733", sourceApp: src("com.figma.Desktop", "Figma")),
  ClipboardItem(
    content: "640\u{00D7}400", type: .image, imageData: imagePNG,
    sourceApp: src("com.apple.Preview", "Preview")),
  ClipboardItem(
    content: "https://github.com/apple/swift", type: .url,
    sourceApp: src("com.apple.Safari", "Safari"),
    linkMetadata: LinkMetadata(
      title: "apple/swift: The Swift Programming Language",
      url: URL(string: "https://github.com/apple/swift")!)),
  ClipboardItem(
    content:
      "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump!",
    sourceApp: src("com.tinyspeck.slackmacgap", "Slack")),
  ClipboardItem(content: "Meeting moved to 3pm", sourceApp: src("com.apple.MobileSMS", "Messages")),
]
for item in seed {
  if item.type == .image, let data = item.imageData { ImageStore.shared.save(data: data, for: item.id) }
  clipboard.addToHistory(item: item)
  spin(0.03)
}
spin(0.3)

// Preferences can outlive the scratch home (cfprefsd caches them), so start clean every run
for board in pinboards.pinboards { pinboards.deletePinboard(board) }
if pinboards.pinboards.isEmpty {
  let fav = pinboards.createPinboard(name: "Favorites", color: .blue)
  _ = pinboards.createPinboard(name: "Work", color: .green)
  if let first = clipboard.history.first { pinboards.addItem(first.id, to: fav) }
}
for item in clipboard.history.prefix(4).reversed() { stack.stackItems.append(item) }

func render<V: View>(_ name: String, size: CGSize, wait: TimeInterval = 0.8, _ view: () -> V) {
  if let only = only, !only.contains(name) { return }
  for dark in [false, true] {
    let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
    app.appearance = appearance
    let host = NSHostingView(rootView: view().frame(width: size.width, height: size.height))
    host.appearance = appearance
    host.frame = NSRect(origin: .zero, size: size)
    let window = NSWindow(
      contentRect: NSRect(x: -6000, y: -6000, width: size.width, height: size.height),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = appearance
    window.backgroundColor = .windowBackgroundColor
    window.contentView = host
    window.orderBack(nil)
    host.layoutSubtreeIfNeeded()
    spin(wait)
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(
      "\(tag)-\(name)-\(dark ? "dark" : "light").png")
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.lastPathComponent)")
    window.close()
  }
}

render("drawer", size: CGSize(width: 1500, height: settings.drawerHeight)) {
  ContentView(
    clipboardManager: clipboard, navigationState: nav, pinboardManager: pinboards,
    settings: settings, dismiss: { _ in })
}

DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { nav.shouldFocusSearch = true }
render("drawer-search", size: CGSize(width: 1500, height: settings.drawerHeight), wait: 1.0) {
  ContentView(
    clipboardManager: clipboard, navigationState: nav, pinboardManager: pinboards,
    settings: settings, dismiss: { _ in })
}

render("settings", size: CGSize(width: 680, height: 480)) {
  SettingsView(
    onClose: {}, settings: settings, clipboardManager: clipboard, pinboardManager: pinboards,
    snippetManager: snippets)
}
render("settings-appearance", size: CGSize(width: 500, height: 620)) {
  AppearanceSettingsPane(settings: settings).background(Brand.white)
}
render("settings-shortcuts", size: CGSize(width: 500, height: 760)) {
  ShortcutsSettingsPane(settings: settings).background(Brand.white)
}
render("settings-capture", size: CGSize(width: 500, height: 300)) {
  ScreenCaptureSettingsPane(settings: settings).background(Brand.white)
}
render("settings-snippets", size: CGSize(width: 500, height: 480)) {
  SnippetsSettingsPane(snippetManager: snippets).background(Brand.white)
}
render("settings-privacy", size: CGSize(width: 500, height: 620)) {
  PrivacySettingsPane(settings: settings).background(Brand.white)
}
render("settings-storage", size: CGSize(width: 500, height: 620)) {
  StorageSettingsPane(settings: settings, clipboardManager: clipboard, pinboardManager: pinboards, snippetManager: snippets)
    .background(Brand.white)
}
render("settings-about", size: CGSize(width: 500, height: 620)) {
  AboutSettingsPane().background(Brand.white)
}

// The post-capture thumbnail with its buttons showing, over a light and a dark capture
func captureSample(light: Bool) -> NSImage {
  let size = NSSize(width: 480, height: 300)
  let image = NSImage(size: size)
  image.lockFocus()
  (light ? NSColor.white : NSColor(white: 0.1, alpha: 1)).setFill()
  NSRect(origin: .zero, size: size).fill()
  (light ? NSColor(white: 0.82, alpha: 1) : NSColor(white: 0.3, alpha: 1)).setFill()
  for i in 0..<6 { NSRect(x: 30, y: 30 + i * 42, width: 380 - i * 40, height: 16).fill() }
  image.unlockFocus()
  return image
}
render("capture-thumbnail", size: CGSize(width: 560, height: 190)) {
  HStack(spacing: 20) {
    FloatingOverlayView(image: captureSample(light: true), showsActions: true, onCopy: {}, onSave: {}, onAnnotate: {}, onClose: {})
    FloatingOverlayView(image: captureSample(light: false), showsActions: true, onCopy: {}, onSave: {}, onAnnotate: {}, onClose: {})
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.gray)
}

render("onboarding", size: OnboardingLayout.windowSize) {
  OnboardingView(settings: settings, onComplete: {})
}
render("onboarding-shortcut", size: OnboardingLayout.windowSize) {
  OnboardingView(settings: settings, initialStep: 1, onComplete: {})
}
render("onboarding-done", size: OnboardingLayout.windowSize) {
  OnboardingView(settings: settings, initialStep: 2, onComplete: {})
}

render("pastestack", size: CGSize(width: 340, height: 520)) {
  PasteStackView(pasteStackManager: stack, navigationState: nav, onClose: {}, dismiss: { _ in })
}

func preview(_ name: String, _ match: (ClipboardItem) -> Bool, _ size: CGSize) {
  guard let item = clipboard.history.first(where: match) else { return }
  render(name, size: size) {
    PreviewView(
      item: item, clipboardManager: clipboard, pinboardManager: pinboards,
      editingState: PreviewEditingState(), arrowXPosition: size.width / 2, onDismiss: {},
      onPaste: { _ in })
  }
}
preview("preview-text", { $0.content.hasPrefix("The quick") }, CGSize(width: 500, height: 412))
preview("preview-color", { $0.content == "#FF5733" }, CGSize(width: 500, height: 412))
preview("preview-code", { $0.content.hasPrefix("func greet") }, CGSize(width: 500, height: 412))
preview("preview-json", { $0.content.hasPrefix("{") }, CGSize(width: 500, height: 412))
preview("preview-image", { $0.type == .image }, CGSize(width: 600, height: 500))
preview("preview-url", { $0.type == .url }, CGSize(width: 800, height: 650))
