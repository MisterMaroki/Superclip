//
//  PreviewView.swift
//  Superclip
//

import SwiftUI

struct PreviewView: View {
    let item: ClipboardItem
    let clipboardManager: ClipboardManager
    let onDismiss: () -> Void
    let onPaste: (String) -> Void
    
    @State private var editableContent: String
    @State private var isEditing: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    init(item: ClipboardItem, clipboardManager: ClipboardManager, onDismiss: @escaping () -> Void, onPaste: @escaping (String) -> Void) {
        self.item = item
        self.clipboardManager = clipboardManager
        self.onDismiss = onDismiss
        self.onPaste = onPaste
        self._editableContent = State(initialValue: item.content)
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
        item.sourceApp?.accentColor ?? Color(nsColor: .systemGray)
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
            regularPreviewView
        }
    }
    
    var regularPreviewView: some View {
        VStack(spacing: 0) {
            // Header with close button, type label, and actions
            HStack(spacing: 12) {
                // Close button
                Button {
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
                    
                    // Edit button
                    Button {
                        isEditing.toggle()
                        if isEditing {
                            isTextEditorFocused = true
                        }
                    } label: {
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isEditing ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(isEditing ? appColor : Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
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
                default:
                    textPreview
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
            
            // Footer with stats
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    var textPreview: some View {
        ScrollView {
            if isEditing {
                TextEditor(text: $editableContent)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($isTextEditorFocused)
                    .padding(16)
            } else {
                Text(editableContent)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
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
    
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func showInFinder(urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

struct FilePreviewRow: View {
    let url: URL
    
    private var isImageFile: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    private var imageFromFile: NSImage? {
        guard isImageFile else { return nil }
        return NSImage(contentsOf: url)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show image preview if it's an image file
            if isImageFile, let image = imageFromFile {
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
                    Text(url.deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
