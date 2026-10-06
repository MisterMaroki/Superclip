//
//  ShareViewController.swift
//  Superclip share extension
//
//  "Save to Superclip" in the share sheet. It takes whatever was shared (text,
//  a link, images), drops it in the shared inbox for the app, shows a brief
//  confirmation, and gets out of the way.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let host = UIHostingController(rootView: ShareConfirmation(model: model))
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        Task { await save() }
    }

    private func save() async {
        guard SharedInbox.isAvailable else {
            model.state = .failed("Superclip can\u{2019}t receive shared items in this build.")
            await finish(after: 1.8)
            return
        }

        let inputs = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var saved = 0
        var preview: String?

        for input in inputs {
            let title = input.attributedContentText?.string
            for provider in input.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let data = await loadImageData(from: provider),
                        SharedInbox.add(SharedInbox.Item(imageData: data))
                    {
                        saved += 1
                        preview = preview ?? "Image"
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL,
                        !url.isFileURL, SharedInbox.add(SharedInbox.Item(text: url.absoluteString, title: title))
                    {
                        saved += 1
                        preview = preview ?? (url.host ?? url.absoluteString)
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
                        SharedInbox.add(SharedInbox.Item(text: text))
                    {
                        saved += 1
                        preview = preview ?? text
                    }
                }
            }
        }

        if saved > 0 {
            model.state = .saved(count: saved, preview: preview ?? "")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            model.state = .failed("There was nothing here Superclip could save.")
        }
        await finish(after: saved > 0 ? 1.1 : 1.8)
    }

    private func loadImageData(from provider: NSItemProvider) async -> Data? {
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) else { return nil }
        if let url = item as? URL { return try? Data(contentsOf: url) }
        if let image = item as? UIImage { return image.pngData() }
        return item as? Data
    }

    private func finish(after seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
        extensionContext?.completeRequest(returningItems: nil)
    }
}

@MainActor
final class ShareModel: ObservableObject {
    enum State: Equatable {
        case saving
        case saved(count: Int, preview: String)
        case failed(String)
    }

    @Published var state: State = .saving
}

/// A small card in the middle of a dimmed screen: what happened, in one line.
struct ShareConfirmation: View {
    @ObservedObject var model: ShareModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(accent).frame(height: 3)
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Ink.onInk)
                        .frame(width: 44, height: 44)
                        .background(Ink.ink)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Ink.ink)
                        if !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: 13))
                                .foregroundStyle(Ink.ink2)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .background(Ink.surface)
            .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
            .padding(.horizontal, 28)
            .animation(.snappy(duration: 0.18), value: model.state)
        }
    }

    private var title: String {
        switch model.state {
        case .saving: return "Saving to Superclip"
        case .saved(let count, _): return count == 1 ? "Saved to Superclip" : "Saved \(count) clips to Superclip"
        case .failed: return "Couldn\u{2019}t save"
        }
    }

    private var detail: String {
        switch model.state {
        case .saving: return ""
        case .saved(_, let preview): return preview
        case .failed(let reason): return reason
        }
    }

    private var symbol: String {
        switch model.state {
        case .saving: return "arrow.down"
        case .saved: return "checkmark"
        case .failed: return "exclamationmark"
        }
    }

    private var accent: Color {
        if case .failed = model.state { return Ink.danger }
        return Ink.ink
    }
}
