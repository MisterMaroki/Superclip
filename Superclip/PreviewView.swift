//
//  PreviewView.swift
//  Superclip
//

import SwiftUI
import AVKit
import WebKit

struct PreviewView: View {
    let item: ClipboardItem
    let clipboardManager: ClipboardManager
    @ObservedObject var editingState: PreviewEditingState
    let arrowXPosition: CGFloat // X position of the arrow within the view
    let onDismiss: () -> Void
    let onPaste: (String) -> Void
    var onOpenEditor: ((ClipboardItem, NSRect) -> Void)?
    var onCloseAll: (() -> Void)? // Callback to close both preview and drawer

    @State private var editableContent: String
    @State private var originalContent: String
    @FocusState private var isTextEditorFocused: Bool

    private let arrowHeight: CGFloat = 10
    private let arrowWidth: CGFloat = 20

    private var isEditing: Bool {
        get { editingState.isEditing }
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

    init(item: ClipboardItem, clipboardManager: ClipboardManager, editingState: PreviewEditingState, arrowXPosition: CGFloat = 250, onDismiss: @escaping () -> Void, onPaste: @escaping (String) -> Void, onOpenEditor: ((ClipboardItem, NSRect) -> Void)? = nil, onCloseAll: (() -> Void)? = nil) {
        self.item = item
        self.clipboardManager = clipboardManager
        self.editingState = editingState
        self.arrowXPosition = arrowXPosition
        self.onDismiss = onDismiss
        self.onPaste = onPaste
        self.onOpenEditor = onOpenEditor
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
        // For images, use the dedicated ImageEditorView
        if item.type == .image, let nsImage = item.nsImage {
            ImageEditorView(
                originalImage: nsImage,
                clipboardManager: clipboardManager,
                onDismiss: onDismiss
            )
        } else {
            previewWithArrow
        }
    }

    var previewWithArrow: some View {
        ZStack {
            // Explicit transparent base
            Color.clear

            VStack(spacing: 0) {
                regularPreviewView

                // Stylized arrow pointing down to the card
                GeometryReader { geometry in
                    let clampedX = max(arrowWidth / 2 + 16, min(arrowXPosition, geometry.size.width - arrowWidth / 2 - 16))

                    ZStack {
                     
                        // Main arrow body with gradient
                        ArrowShape()
                            .fill(
                                Color.black.opacity(0.3)
                                
                            )
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
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                
                // Type label
                HStack(spacing: 6) {
                    if let icon = item.sourceApp?.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Text(item.type.rawValue.capitalized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    // Copy type indicator
                    Menu {
                        Button("Plain Text") { }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "circle")
                                .font(.system(size: 8))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 50)
                    
                    // Share button
                    Button {
                        // Share action
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    // Edit button - opens rich text editor in new window
                    if item.type == .text || item.type == .url {
                        Button {
                            // Get current window frame to position editor
                            if let window = NSApp.keyWindow {
                                onOpenEditor?(item, window.frame)
                            }
                        } label: {
                            Text("Edit")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))
            
            // Content area
            Group {
                switch item.type {
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
            
            // Footer
            Group {
                if item.type == .url {
                    // Footer for URL types: URL on left, Open in browser button on right
                    HStack {
                        if let url = URL(string: item.content) {
                            Text(url.absoluteString)
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
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
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(appColor)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.3))
                } else {
                    // Footer with stats for other types
                    HStack {
                        Text("\(characterCount) characters")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        Text("·")
                            .foregroundStyle(.secondary.opacity(0.5))
                        
                        Text("\(wordCount) \(wordCount == 1 ? "word" : "words")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        Text("·")
                            .foregroundStyle(.secondary.opacity(0.5))
                        
                        Text("\(lineCount) \(lineCount == 1 ? "line" : "lines")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
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
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(appColor)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.3))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        // subtle lighter shadow below
        .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: -15)
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
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func showInFinder(urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
    
    private var defaultBrowserName: String {
        // Get default browser name
        guard let url = URL(string: "https://example.com"),
              let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            return "Browser"
        }
        
        // Get bundle identifier to identify the browser
        if let bundle = Bundle(url: defaultBrowserURL),
           let bundleId = bundle.bundleIdentifier {
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
                "com.arc.browser": "Arc"
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
    private static let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
    
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
    
    private var imageFromFile: NSImage? {
        guard isImageFile else { return nil }
        return NSImage(contentsOf: url)
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
                    .cornerRadius(8)
                    .clipped()
            } else if isAudioFile {
                AudioPlayerView(url: url)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
            } else if isImageFile, let image = imageFromFile {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 250)
                    .cornerRadius(8)
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
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        if isVideoFile || isAudioFile || isImageFile {
                            Text("•")
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text(mediaTypeLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .separatorColor).opacity(0.2))
            .cornerRadius(8)
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
    
    var body: some View {
        VStack(spacing: 12) {
            // Waveform visualization placeholder
            HStack(spacing: 2) {
                ForEach(0..<40, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < Int((currentTime / max(duration, 1)) * 40) ? Color.purple : Color.purple.opacity(0.3))
                        .frame(width: 4, height: CGFloat.random(in: 10...40))
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
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                
                // Time slider
                VStack(spacing: 4) {
                    Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
                        if !editing {
                            player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                        }
                    }
                    .tint(.purple)
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatTime(duration))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
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
        
        // Observe playback end
        NotificationCenter.default.addObserver(
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
        textView.textStorage?.setAttributedString(attributedString)
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.textStorage?.setAttributedString(attributedString)
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
            // Handle error if needed
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
