//
//  PreviewView.swift
//  Superclip
//

import AVKit
import SwiftUI
import WebKit

struct PreviewView: View {
  let item: ClipboardItem
  let clipboardManager: ClipboardManager
  @ObservedObject var pinboardManager: PinboardManager
  @ObservedObject var editingState: PreviewEditingState
  let arrowXPosition: CGFloat  // X position of the arrow within the view
  let onDismiss: () -> Void
  let onPaste: (String) -> Void
  var onOpenEditor: ((ClipboardItem, NSRect) -> Void)?
  var onOpenImageEditor: ((ClipboardItem) -> Void)?
  var onCloseAll: (() -> Void)?  // Callback to close both preview and drawer

  @State private var editableContent: String
  @State private var originalContent: String
  @FocusState private var isTextEditorFocused: Bool

  private let arrowHeight: CGFloat = 10
  private let arrowWidth: CGFloat = 20

  private var isEditing: Bool {
    editingState.isEditing
  }

  private func setEditing(_ value: Bool) {
    editingState.isEditing = value
  }

  private func cancelEditing() {
    // Reset to original content
    editableContent = originalContent
    setEditing(false)
  }

  private func saveEditing() {
    // Save changes to the clipboard item
    clipboardManager.updateItemContent(item, newContent: editableContent)
    originalContent = editableContent
    setEditing(false)
  }

  init(
    item: ClipboardItem, clipboardManager: ClipboardManager, pinboardManager: PinboardManager,
    editingState: PreviewEditingState, arrowXPosition: CGFloat = 250,
    onDismiss: @escaping () -> Void, onPaste: @escaping (String) -> Void,
    onOpenEditor: ((ClipboardItem, NSRect) -> Void)? = nil,
    onOpenImageEditor: ((ClipboardItem) -> Void)? = nil,
    onCloseAll: (() -> Void)? = nil
  ) {
    self.item = item
    self.clipboardManager = clipboardManager
    self.pinboardManager = pinboardManager
    self.editingState = editingState
    self.arrowXPosition = arrowXPosition
    self.onDismiss = onDismiss
    self.onPaste = onPaste
    self.onOpenEditor = onOpenEditor
    self.onOpenImageEditor = onOpenImageEditor
    self.onCloseAll = onCloseAll
    self._editableContent = State(initialValue: item.content)
    self._originalContent = State(initialValue: item.content)
  }

  var characterCount: Int {
    editableContent.count
  }

  var wordCount: Int {
    let words = editableContent.split { $0.isWhitespace || $0.isNewline }
    return words.count
  }

  var lineCount: Int {
    if editableContent.isEmpty { return 0 }
    return editableContent.components(separatedBy: .newlines).count
  }

  var appColor: Color {
    Color(nsColor: .systemGray)
  }

  var body: some View {
    previewWithArrow
  }

  var previewWithArrow: some View {
    ZStack {
      // Explicit transparent base
      Color.clear

      VStack(spacing: 0) {
        regularPreviewView

        // Stylized arrow pointing down to the card
        GeometryReader { geometry in
          let clampedX = max(
            arrowWidth / 2 + 16, min(arrowXPosition, geometry.size.width - arrowWidth / 2 - 16))

          ZStack {

            // Main arrow body with gradient
            ArrowShape()
              .fill(Brand.gray300)
              .frame(width: arrowWidth, height: arrowHeight)

          }
          .position(x: clampedX, y: arrowHeight / 2)
        }
        .frame(height: arrowHeight)
      }
    }
  }

  var regularPreviewView: some View {
    VStack(spacing: 0) {
      // Header with close button, type label, and actions
      HStack(spacing: 12) {
        // Close button
        Button {
          if isEditing {
            cancelEditing()
          }
          onDismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 16))
            .foregroundStyle(.primary.opacity(0.6))
        }
        .buttonStyle(.plain)
        .help("Close preview (Esc)")
        .accessibilityLabel("Close preview")

        // Type label
        HStack(spacing: 6) {
          if let icon = item.sourceApp?.icon {
            Image(nsImage: icon)
              .resizable()
              .frame(width: 16, height: 16)
          }
          Text(item.typeLabel)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
        }

        Spacer()

        // Action buttons
        HStack(spacing: 8) {
          // Move to pinboard dropdown
          Menu {
            ForEach(pinboardManager.pinboards) { pinboard in
              Toggle(
                isOn: Binding(
                  get: { pinboard.itemIds.contains(item.id) },
                  set: { isOn in
                    if isOn {
                      pinboardManager.addItem(item.id, to: pinboard)
                    } else {
                      pinboardManager.removeItem(item.id, from: pinboard)
                    }
                  }
                )
              ) {
                Label {
                  Text(pinboard.name)
                } icon: {
                  Image(nsImage: coloredCircleImage(color: pinboard.color.nsColor))
                }
              }
            }

            if !pinboardManager.pinboards.isEmpty {
              Divider()
            }

            Button {
              _ = pinboardManager.createPinboard(name: "Untitled")
            } label: {
              Label("New Pinboard", systemImage: "plus")
            }
          } label: {
            PinboardDropdownLabel(item: item, pinboardManager: pinboardManager)
          }
          .menuStyle(.borderlessButton)
          .fixedSize()

          // Share button
          ShareButtonView(item: item)
            .frame(width: 20, height: 20)

          // Edit button - opens rich text editor or image annotation editor in new window
          if item.type == .text || item.type == .url {
            Button {
              // Get current window frame to position editor
              if let window = NSApp.keyWindow {
                onOpenEditor?(item, window.frame)
              }
            } label: {
              Text("Edit")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.1))
            }
            .buttonStyle(.plain)
          } else if item.type == .image {
            Button {
              onOpenImageEditor?(item)
            } label: {
              Text("Edit")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.1))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Brand.gray100)

      // Content area
      Group {
        switch item.type {
        case .image:
          imagePreview
        case .file:
          filePreview
        case .url:
          urlPreview
        default:
          textPreview
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))

      // Quick Actions bar (only shown when actions are available)
      QuickActionsBar(item: item)

      // Footer
      Group {
        if item.type == .image {
          // Footer for image types: dimensions on left, Copy to Clipboard on right
          HStack {
            // Pixel dimensions, the same figure the card shows. NSImage.size
            // is in points, which halves a Retina screenshot's numbers.
            if let dimensions = item.imageDimensions {
              Text(dimensions)
                .font(.system(size: 11))
                .foregroundStyle(Brand.gray600)
            }

            Spacer()

            Button {
              copyImageToClipboard()
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "doc.on.clipboard")
                  .font(.system(size: 10))
                Text("Copy to Clipboard")
                  .font(.system(size: 11, weight: .medium))
              }
              .foregroundStyle(Brand.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Brand.black)
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(Brand.gray100)
        } else if item.type == .url {
          // Footer for URL types: URL on left, Open in browser button on right
          HStack {
            if let url = URL(string: item.content) {
              Text(url.absoluteString)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            }

            Spacer()

            Button {
              openInBrowser()
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "safari")
                  .font(.system(size: 10))
                Text("Open in \(defaultBrowserName)")
                  .font(.system(size: 11, weight: .medium))
              }
              .foregroundStyle(Brand.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Brand.black)
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(Brand.gray100)
        } else {
          // Footer with stats for other types
          HStack {
            Text("\(characterCount) characters")
              .font(.system(size: 11))
              .foregroundStyle(Brand.gray600)

            Text("·")
              .font(.system(size: 11))
              .foregroundStyle(Brand.gray500)

            Text("\(wordCount) \(wordCount == 1 ? "word" : "words")")
              .font(.system(size: 11))
              .foregroundStyle(Brand.gray600)

            Text("·")
              .font(.system(size: 11))
              .foregroundStyle(Brand.gray500)

            Text("\(lineCount) \(lineCount == 1 ? "line" : "lines")")
              .font(.system(size: 11))
              .foregroundStyle(Brand.gray600)

            Spacer()

            // Show in Finder button (only for files)
            if item.type == .file, let urls = item.fileURLs, !urls.isEmpty {
              Button {
                showInFinder(urls: urls)
              } label: {
                HStack(spacing: 4) {
                  Image(systemName: "folder")
                    .font(.system(size: 10))
                  Text("Show in Finder")
                    .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Brand.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Brand.black)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(Brand.gray100)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Brand.white)
    .clipShape(Rectangle())
    .overlay(
      Rectangle()
        .stroke(Brand.gray300, lineWidth: 1)
    )

  }

  var textPreview: some View {
    ScrollView {
      if let attributedString = item.attributedString {
        // Display rich text content
        AttributedTextView(attributedString: attributedString)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.top, 24)
          .padding(.bottom, 16)
      } else if let code = highlightedCode {
        // Code: monospaced and coloured, as the "Syntax highlighting" setting promises
        AttributedTextView(attributedString: code)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.top, 24)
          .padding(.bottom, 16)
      } else {
        Text(editableContent)
          .font(.system(size: 13))
          .foregroundStyle(.primary)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.top, 24)
          .padding(.bottom, 16)
      }
    }
  }

  /// The clip as highlighted code, when highlighting is on and it looks like code.
  private var highlightedCode: NSAttributedString? {
    guard UserDefaults.standard.bool(forKey: "Superclip.syntaxHighlighting"),
      let highlighted = SyntaxHighlighter.highlight(editableContent)
    else { return nil }
    // Cards use 11pt; the preview has room for a more readable size
    let sized = NSMutableAttributedString(attributedString: highlighted)
    sized.addAttribute(
      .font, value: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular),
      range: NSRange(location: 0, length: sized.length))
    return sized
  }

  var filePreview: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        if let urls = item.fileURLs {
          ForEach(urls, id: \.self) { url in
            FilePreviewRow(url: url)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }

  var imagePreview: some View {
    ZStack {
      CheckerboardBackground(first: Brand.gray100, second: Brand.gray200)

      if let nsImage = item.nsImage {
        Image(nsImage: nsImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  var urlPreview: some View {
    Group {
      if let url = URL(string: item.content) {
        WebView(url: url)
      } else {
        // Fallback to text preview if URL is invalid
        textPreview
      }
    }
  }

  private func isImageFile(_ url: URL) -> Bool {
    let imageExtensions = [
      "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif",
    ]
    return imageExtensions.contains(url.pathExtension.lowercased())
  }

  private func showInFinder(urls: [URL]) {
    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }

  private var defaultBrowserName: String {
    // Get default browser name
    guard let url = URL(string: "https://example.com"),
      let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: url)
    else {
      return "Browser"
    }

    // Get bundle identifier to identify the browser
    if let bundle = Bundle(url: defaultBrowserURL),
      let bundleId = bundle.bundleIdentifier
    {
      // Map common browser bundle IDs to friendly names
      let browserNames: [String: String] = [
        "com.apple.Safari": "Safari",
        "com.google.Chrome": "Chrome",
        "com.microsoft.edgemac": "Edge",
        "com.brave.Browser": "Brave",
        "com.operasoftware.Opera": "Opera",
        "org.mozilla.firefox": "Firefox",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "company.thebrowser.Browser": "Arc",
        "com.arc.browser": "Arc",
      ]

      if let name = browserNames[bundleId] {
        return name
      }
    }

    // Fallback: use the app name from the bundle
    let browserName = defaultBrowserURL.deletingPathExtension().lastPathComponent
    // Remove " Helper" suffix if present (e.g., "Arc Helper" -> "Arc")
    let cleanedName = browserName.replacingOccurrences(of: " Helper", with: "")
    // Capitalize first letter
    return cleanedName.prefix(1).capitalized + cleanedName.dropFirst()
  }

  private func copyImageToClipboard() {
    // Through the manager, so the existing card moves to the front. Writing
    // the pasteboard directly was picked up by the poll as a new, differently
    // encoded image and added a duplicate card.
    clipboardManager.copyToClipboard(item)
  }

  private func openInBrowser() {
    guard let url = URL(string: item.content) else { return }
    NSWorkspace.shared.open(url)
    // Close both preview and drawer
    onCloseAll?()
  }
}

struct FilePreviewRow: View {
  let url: URL

  // Media file extensions
  private static let videoExtensions = ["mp4", "mov", "avi", "mkv", "webm", "m4v", "wmv", "flv"]
  private static let audioExtensions = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff"]
  private static let imageExtensions = [
    "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif",
  ]

  private var isImageFile: Bool {
    Self.imageExtensions.contains(url.pathExtension.lowercased())
  }

  private var isVideoFile: Bool {
    Self.videoExtensions.contains(url.pathExtension.lowercased())
  }

  private var isAudioFile: Bool {
    Self.audioExtensions.contains(url.pathExtension.lowercased())
  }

  private var isGIF: Bool {
    url.pathExtension.lowercased() == "gif"
  }

  private var mediaTypeLabel: String {
    let ext = url.pathExtension.uppercased()
    if isVideoFile {
      return "Video • \(ext)"
    } else if isAudioFile {
      return "Audio • \(ext)"
    } else if isImageFile {
      return "Image • \(ext)"
    }
    return ext
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Show appropriate media preview
      if isVideoFile {
        VideoPlayerView(url: url)
          .frame(maxWidth: .infinity, maxHeight: 280)
          .clipped()
      } else if isAudioFile {
        AudioPlayerView(url: url)
          .frame(maxWidth: .infinity)
      } else if isImageFile {
        // Cached, downsampled load — full NSImage(contentsOf:) decode in
        // body re-runs on every render of the preview.
        FileImageThumbnailView(url: url)
          .frame(maxWidth: .infinity, maxHeight: 250)
          .background(Color.black.opacity(0.1))
      }

      // File info row
      HStack(spacing: 10) {
        if let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
          Image(nsImage: icon)
            .resizable()
            .frame(width: 32, height: 32)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(url.lastPathComponent)
            .font(.system(size: 13, weight: .medium))

          HStack(spacing: 8) {
            Text(url.deletingLastPathComponent().path)
              .font(.system(size: 11))
              .foregroundStyle(Brand.gray600)
              .lineLimit(1)
              .truncationMode(.middle)

            if isVideoFile || isAudioFile || isImageFile {
              Text("•")
                .foregroundStyle(Brand.gray500)
              Text(mediaTypeLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Brand.gray600)
            }
          }
        }

        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(nsColor: .separatorColor).opacity(0.2))
    }
  }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
  let url: URL
  @State private var player: AVPlayer?
  @State private var isPlaying = false

  var body: some View {
    ZStack {
      if let player = player {
        VideoPlayer(player: player)
          .onAppear {
            // Don't auto-play
            player.pause()
          }
          .onDisappear {
            player.pause()
          }
      } else {
        // Loading state
        Rectangle()
          .fill(Color.black.opacity(0.3))
          .overlay {
            ProgressView()
              .scaleEffect(0.8)
          }
      }
    }
    .onAppear {
      player = AVPlayer(url: url)
    }
  }
}

// MARK: - Audio Player View

struct AudioPlayerView: View {
  let url: URL
  @State private var player: AVPlayer?
  @State private var isPlaying = false
  @State private var currentTime: Double = 0
  @State private var duration: Double = 0
  @State private var timeObserver: Any?
  @State private var endObserver: NSObjectProtocol?

  /// Stable pseudo-random bar heights — `CGFloat.random` in body makes the
  /// waveform re-randomize on every render (10×/sec during playback).
  private static let barHeights: [CGFloat] = (0..<40).map { i in
    10 + CGFloat((i * 37 + 13) % 31)
  }

  var body: some View {
    VStack(spacing: 12) {
      // Waveform visualization placeholder
      HStack(spacing: 2) {
        ForEach(0..<40, id: \.self) { i in
          Rectangle()
            .fill(
              i < Int((currentTime / max(duration, 1)) * 40)
                ? Brand.gray500 : Brand.gray500.opacity(0.3)
            )
            .frame(width: 4, height: Self.barHeights[i])
        }
      }
      .frame(height: 50)
      .padding(.horizontal, 16)
      .padding(.top, 12)

      // Playback controls
      HStack(spacing: 20) {
        // Play/Pause button
        Button {
          togglePlayback()
        } label: {
          Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(Brand.gray500)
        }
        .buttonStyle(.plain)

        // Time slider
        VStack(spacing: 4) {
          Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
            if !editing {
              player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
            }
          }
          .tint(Brand.black)

          HStack {
            Text(formatTime(currentTime))
              .font(.system(size: 10, design: .monospaced))
              .foregroundStyle(Brand.gray600)
            Spacer()
            Text(formatTime(duration))
              .font(.system(size: 10, design: .monospaced))
              .foregroundStyle(Brand.gray600)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 12)
    }
    .background(Color(nsColor: .separatorColor).opacity(0.2))
    .onAppear {
      setupPlayer()
    }
    .onDisappear {
      cleanup()
    }
  }

  private func setupPlayer() {
    let avPlayer = AVPlayer(url: url)
    self.player = avPlayer

    // Get duration
    let asset = AVAsset(url: url)
    Task {
      if let durationValue = try? await asset.load(.duration) {
        await MainActor.run {
          self.duration = durationValue.seconds
        }
      }
    }

    // Add time observer
    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
    timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
      self.currentTime = time.seconds
    }

    // Observe playback end — keep the token so cleanup can remove it.
    // An unremoved block observer leaks (and keeps firing) for the app's
    // lifetime every time an audio preview is opened.
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: avPlayer.currentItem,
      queue: .main
    ) { _ in
      self.isPlaying = false
      self.player?.seek(to: .zero)
      self.currentTime = 0
    }
  }

  private func togglePlayback() {
    guard let player = player else { return }

    if isPlaying {
      player.pause()
    } else {
      player.play()
    }
    isPlaying.toggle()
  }

  private func cleanup() {
    player?.pause()
    if let observer = timeObserver {
      player?.removeTimeObserver(observer)
      timeObserver = nil
    }
    if let observer = endObserver {
      NotificationCenter.default.removeObserver(observer)
      endObserver = nil
    }
    player = nil
  }

  private func formatTime(_ time: Double) -> String {
    guard time.isFinite else { return "0:00" }
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

// MARK: - Attributed Text View

struct AttributedTextView: NSViewRepresentable {
  let attributedString: NSAttributedString

  func makeNSView(context: Context) -> NSTextView {
    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.backgroundColor = .clear
    textView.textContainerInset = .zero
    textView.textContainer?.lineFragmentPadding = 0
    textView.isVerticallyResizable = false
    textView.isHorizontallyResizable = false
    textView.textContainer?.widthTracksTextView = false
    // Rich text saved from a light-mode app carries black text; let AppKit
    // remap it so it stays readable on a dark panel
    textView.usesAdaptiveColorMappingForDarkAppearance = true
    textView.textStorage?.setAttributedString(attributedString)
    return textView
  }

  func updateNSView(_ nsView: NSTextView, context: Context) {
    // Resetting identical text discards the selection and redoes layout
    if nsView.textStorage?.isEqual(to: attributedString) != true {
      nsView.textStorage?.setAttributedString(attributedString)
    }
  }

  /// Report the height the text really needs at the offered width. A bare
  /// NSTextView has no intrinsic size, so inside a ScrollView SwiftUI gave it
  /// an arbitrary height and the text was drawn offset, with only its last
  /// lines visible.
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
    guard let container = nsView.textContainer, let layoutManager = nsView.layoutManager,
      let width = proposal.width, width > 0, width.isFinite
    else { return nil }
    container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    layoutManager.ensureLayout(for: container)
    let used = layoutManager.usedRect(for: container)
    return CGSize(width: width, height: ceil(used.height))
  }
}

// MARK: - Web View

struct WebView: NSViewRepresentable {
  let url: URL
  @State private var isLoading = true

  func makeNSView(context: Context) -> WKWebView {
    let webView = WKWebView()
    webView.navigationDelegate = context.coordinator
    webView.allowsBackForwardNavigationGestures = false
    webView.allowsMagnification = false
    // No opaque white sheet before the page paints: in dark mode that was a
    // full-size white flash on every link preview.
    webView.setValue(false, forKey: "drawsBackground")
    webView.underPageBackgroundColor = .clear
    return webView
  }

  func updateNSView(_ nsView: WKWebView, context: Context) {
    if nsView.url != url {
      let request = URLRequest(url: url)
      nsView.load(request)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      // Page loaded
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      showFailure(in: webView, error: error)
    }

    func webView(
      _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      showFailure(in: webView, error: error)
    }

    /// Offline or unreachable: say so instead of leaving an empty rectangle.
    private func showFailure(in webView: WKWebView, error: Error) {
      // A cancelled load (the user moved to another card) is not a failure
      if (error as NSError).code == NSURLErrorCancelled { return }
      let html = """
        <html><head><meta name="color-scheme" content="light dark"><style>
        body { font: 13px -apple-system; display: flex; height: 100vh; margin: 0;
               align-items: center; justify-content: center; text-align: center;
               color: #6b6b6b; background: transparent; }
        @media (prefers-color-scheme: dark) { body { color: #a6a6a6; } }
        b { display: block; font-weight: 600; margin-bottom: 4px; }
        </style></head><body><div><b>This page couldn\u{2019}t be loaded</b>
        Check your connection, or open the link in your browser.</div></body></html>
        """
      webView.loadHTMLString(html, baseURL: nil)
    }
  }
}

// MARK: - Arrow Shape

struct ArrowShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()

    // Elegant tapered arrow with curved sides
    let tipY = rect.maxY
    let baseY = rect.minY
    let midX = rect.midX
    let halfWidth = rect.width / 2

    // Start at the tip (bottom center)
    path.move(to: CGPoint(x: midX, y: tipY))

    // Curve up to left corner with inward bow
    path.addQuadCurve(
      to: CGPoint(x: rect.minX, y: baseY),
      control: CGPoint(x: midX - halfWidth * 0.4, y: rect.midY)
    )

    // Flat top with rounded corners
    path.addQuadCurve(
      to: CGPoint(x: rect.minX + 4, y: baseY),
      control: CGPoint(x: rect.minX, y: baseY)
    )

    // Line across top
    path.addLine(to: CGPoint(x: rect.maxX - 4, y: baseY))

    // Right corner
    path.addQuadCurve(
      to: CGPoint(x: rect.maxX, y: baseY),
      control: CGPoint(x: rect.maxX, y: baseY)
    )

    // Curve down to tip with inward bow
    path.addQuadCurve(
      to: CGPoint(x: midX, y: tipY),
      control: CGPoint(x: midX + halfWidth * 0.4, y: rect.midY)
    )

    path.closeSubpath()
    return path
  }
}

// MARK: - Helper for colored circle in menus

func coloredCircleImage(color: NSColor, size: CGFloat = 12) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  color.setFill()
  let rect = NSRect(x: 0, y: 0, width: size, height: size)
  NSBezierPath(ovalIn: rect).fill()
  image.unlockFocus()
  image.isTemplate = false
  return image
}

// MARK: - Pinboard Dropdown Label

private struct PinboardDropdownLabel: View {
  let item: ClipboardItem
  @ObservedObject var pinboardManager: PinboardManager

  var containingPinboards: [Pinboard] {
    pinboardManager.pinboards.filter { $0.itemIds.contains(item.id) }
  }

  var body: some View {
    HStack(spacing: 4) {
      if containingPinboards.isEmpty {
        Image(systemName: "circle")
          .font(.system(size: 8))
          .foregroundStyle(.primary.opacity(0.6))
      } else {
        Image(
          nsImage: combinedPinboardCircles(
            pinboards: containingPinboards, circleSize: 14, spacing: 6)
        )
        .padding(.horizontal, 6)
      }
      Image(systemName: "chevron.down")
        .font(.system(size: 8))
        .foregroundStyle(.primary.opacity(0.6))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.primary.opacity(0.1))
  }
}

private func combinedPinboardCircles(
  pinboards: [Pinboard], circleSize: CGFloat = 12, spacing: CGFloat = 4
) -> NSImage {
  let count = pinboards.count
  guard count > 0 else {
    return NSImage(size: .zero)
  }

  let totalWidth = CGFloat(count) * circleSize + CGFloat(count - 1) * spacing
  let image = NSImage(size: NSSize(width: totalWidth, height: circleSize))

  image.lockFocus()
  for (index, pinboard) in pinboards.enumerated() {
    let x = CGFloat(index) * (circleSize + spacing)
    let rect = NSRect(x: x, y: 0, width: circleSize, height: circleSize)
    pinboard.color.nsColor.setFill()
    NSBezierPath(ovalIn: rect).fill()
  }
  image.unlockFocus()
  image.isTemplate = false

  return image
}

// MARK: - Share Button

struct ShareButtonView: NSViewRepresentable {
  let item: ClipboardItem

  func makeNSView(context: Context) -> NSButton {
    let button = NSButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    button.image = NSImage(
      systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")?
      .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
    button.imageScaling = .scaleProportionallyDown
    button.imagePosition = .imageOnly
    button.isBordered = false
    button.bezelStyle = .inline
    button.target = context.coordinator
    button.action = #selector(Coordinator.showSharePicker(_:))
    // A dynamic system colour. Deriving one with withAlphaComponent froze it
    // to whichever appearance was current at that moment, which left the
    // icon near-white (invisible) on the light preview header.
    button.contentTintColor = .secondaryLabelColor
    button.setContentHuggingPriority(.required, for: .horizontal)
    button.setContentHuggingPriority(.required, for: .vertical)
    return button
  }

  func updateNSView(_ nsView: NSButton, context: Context) {
    context.coordinator.item = item
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(item: item)
  }

  class Coordinator: NSObject, NSSharingServicePickerDelegate {
    var item: ClipboardItem
    var picker: NSSharingServicePicker?

    init(item: ClipboardItem) {
      self.item = item
    }

    @objc func showSharePicker(_ sender: NSButton) {
      let items = shareItems(for: item)
      guard !items.isEmpty else { return }

      AppDelegate.isShareSheetActive = true
      let picker = NSSharingServicePicker(items: items)
      picker.delegate = self
      self.picker = picker
      picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    func sharingServicePicker(
      _ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?
    ) {
      // Clean up after selection
      AppDelegate.isShareSheetActive = false
      self.picker = nil
    }

    private func shareItems(for item: ClipboardItem) -> [Any] {
      switch item.type {
      case .image:
        if let image = item.nsImage {
          return [image]
        }
        return []
      case .file:
        return item.fileURLs ?? []
      case .url:
        // Share URL as string for better compatibility
        return [item.content]
      case .text:
        return [item.content]
      }
    }
  }
}
