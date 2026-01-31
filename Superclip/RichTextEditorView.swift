//
//  RichTextEditorView.swift
//  Superclip
//

import SwiftUI
import AppKit

struct RichTextEditorView: View {
    let item: ClipboardItem
    let clipboardManager: ClipboardManager
    let onSave: (NSAttributedString) -> Void
    let onCancel: () -> Void

    @State private var textView: NSTextView?

    var characterCount: Int {
        textView?.string.count ?? item.content.count
    }

    var wordCount: Int {
        let text = textView?.string ?? item.content
        let words = text.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }

    var lineCount: Int {
        let text = textView?.string ?? item.content
        if text.isEmpty { return 0 }
        return text.components(separatedBy: .newlines).count
    }

    var appColor: Color {
        item.sourceApp?.accentColor ?? Color(nsColor: .systemGray)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with cancel and save buttons
            HStack(spacing: 12) {
                // Cancel button
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                // Formatting toolbar
                HStack(spacing: 4) {
                    FormatButton(icon: "bold", action: { toggleBold() })
                    FormatButton(icon: "italic", action: { toggleItalic() })
                    FormatButton(icon: "underline", action: { toggleUnderline() })

                    Divider()
                        .frame(height: 16)
                        .background(Color.primary.opacity(0.2))

                    FormatButton(icon: "text.alignleft", action: { setAlignment(.left) })
                    FormatButton(icon: "text.aligncenter", action: { setAlignment(.center) })
                    FormatButton(icon: "text.alignright", action: { setAlignment(.right) })
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)

                Spacer()

                // Save button
                Button {
                    saveContent()
                } label: {
                    HStack(spacing: 4) {
                        Text("Save")
                        Text("\u{2318}\u{21A9}")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            // Rich text editor
            RichTextViewRepresentable(
                item: item,
                textView: $textView
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))

            // Footer with stats
            HStack {
                Text("\(characterCount) characters")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text("\u{00B7}")
                    .foregroundStyle(.secondary.opacity(0.5))

                Text("\(wordCount) \(wordCount == 1 ? "word" : "words")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text("\u{00B7}")
                    .foregroundStyle(.secondary.opacity(0.5))

                Text("\(lineCount) \(lineCount == 1 ? "line" : "lines")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                // Keyboard shortcuts hint
                HStack(spacing: 12) {
                    Text("Esc to cancel")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("\u{2318}+Enter to save")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onReceive(NotificationCenter.default.publisher(for: .richTextEditorSave)) { notification in
            // Check if this notification is for our window
            if let panel = notification.object as? RichTextEditorPanel,
               panel.item.id == item.id {
                saveContent()
            }
        }
    }

    private func saveContent() {
        guard let textView = textView else { return }
        let attributedString = textView.attributedString()
        onSave(attributedString)
    }

    private func toggleBold() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        if range.length == 0 { return }

        textView.undoManager?.beginUndoGrouping()

        let currentFont = textView.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 13)
        let fontManager = NSFontManager.shared

        let newFont: NSFont
        if fontManager.traits(of: currentFont).contains(.boldFontMask) {
            newFont = fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
        } else {
            newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
        }

        textView.textStorage?.addAttribute(.font, value: newFont, range: range)
        textView.undoManager?.endUndoGrouping()
    }

    private func toggleItalic() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        if range.length == 0 { return }

        textView.undoManager?.beginUndoGrouping()

        let currentFont = textView.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 13)
        let fontManager = NSFontManager.shared

        let newFont: NSFont
        if fontManager.traits(of: currentFont).contains(.italicFontMask) {
            newFont = fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
        } else {
            newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
        }

        textView.textStorage?.addAttribute(.font, value: newFont, range: range)
        textView.undoManager?.endUndoGrouping()
    }

    private func toggleUnderline() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        if range.length == 0 { return }

        textView.undoManager?.beginUndoGrouping()

        let currentUnderline = textView.textStorage?.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0

        if currentUnderline != 0 {
            textView.textStorage?.removeAttribute(.underlineStyle, range: range)
        } else {
            textView.textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }

        textView.undoManager?.endUndoGrouping()
    }

    private func setAlignment(_ alignment: NSTextAlignment) {
        guard let textView = textView else { return }

        textView.undoManager?.beginUndoGrouping()

        let range = textView.selectedRange()
        let paragraphRange = (textView.string as NSString).paragraphRange(for: range)

        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        textView.textStorage?.addAttribute(.paragraphStyle, value: style, range: paragraphRange)

        textView.undoManager?.endUndoGrouping()
    }
}

struct FormatButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.8))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct RichTextViewRepresentable: NSViewRepresentable {
    let item: ClipboardItem
    @Binding var textView: NSTextView?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesRuler = false
        textView.usesFontPanel = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.labelColor
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        // Set up text container
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // Load content - prefer RTF data if available
        if let rtfData = item.rtfData,
           let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attributedString)
        } else {
            textView.string = item.content
        }

        scrollView.documentView = textView

        DispatchQueue.main.async {
            self.textView = textView
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Update text view reference if needed
        if let tv = nsView.documentView as? NSTextView, textView == nil {
            DispatchQueue.main.async {
                self.textView = tv
            }
        }
    }
}
