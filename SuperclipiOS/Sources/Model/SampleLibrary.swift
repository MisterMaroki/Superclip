//
//  SampleLibrary.swift
//  Superclip for iPhone
//
//  A believable library for trying the app before sync exists: loaded only
//  when the user asks for it (Settings, or the empty state), never silently.
//

import UIKit

enum SampleLibrary {
    static func make(imagesDirectory: URL) -> (clips: [Clip], pinboards: [Pinboard], snippets: [Snippet]) {
        let mac = "MacBook Pro"
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

        let imageName = "sample-gradient.png"
        let image = sampleImage()
        try? image.pngData()?.write(to: imagesDirectory.appendingPathComponent(imageName), options: .atomic)

        func clip(
            _ kind: ClipKind, _ content: String, title: String? = nil, app: String?, device: String,
            minutes: Double, imageFile: String? = nil
        ) -> Clip {
            Clip(
                kind: kind, content: content, title: title, imageFile: imageFile,
                imageWidth: imageFile == nil ? nil : 1200, imageHeight: imageFile == nil ? nil : 750,
                createdAt: ago(minutes), lastUsedAt: ago(minutes), sourceApp: app, device: device)
        }

        let clips = [
            clip(.text, "Running ten minutes late. Order me a flat white?", app: "Messages", device: Clip.thisDevice, minutes: 1),
            clip(.link, "https://developer.apple.com/design/human-interface-guidelines", title: "Human Interface Guidelines", app: "Safari", device: mac, minutes: 4),
            clip(.color, "#FF5733", app: "Figma", device: mac, minutes: 9),
            clip(.code, "func greet(_ name: String) -> String {\n    let greeting = \"Hello, \\(name)!\"\n    return greeting\n}", app: "Xcode", device: mac, minutes: 16),
            clip(.image, "Image", app: "Preview", device: mac, minutes: 31, imageFile: imageName),
            clip(.text, "The best interface is the one you stop noticing. Remove a step, then remove another.", app: "Notes", device: mac, minutes: 48),
            clip(.link, "https://github.com/apple/swift", title: "apple/swift: The Swift Programming Language", app: "Arc", device: mac, minutes: 75),
            clip(.color, "#0A0A0A", app: "Figma", device: mac, minutes: 110),
            clip(.text, "4 Privet Drive, Little Whinging, Surrey", app: "Maps", device: Clip.thisDevice, minutes: 190),
            clip(.code, "git rebase -i HEAD~3\n  pick 1a2b3c4 tidy the drawer\n  squash 5d6e7f8 fix typo", app: "Terminal", device: mac, minutes: 260),
            clip(.color, "#F4F1E8", app: "Figma", device: mac, minutes: 400),
            clip(.text, "hello@superclip.app", app: "Mail", device: mac, minutes: 720),
        ]

        var brand = Pinboard(name: "Brand", tint: .orange)
        brand.clipIDs = clips.filter { $0.kind == .color }.map(\.id)
        var reading = Pinboard(name: "Reading", tint: .blue)
        reading.clipIDs = clips.filter { $0.kind == .link }.map(\.id)
        var replies = Pinboard(name: "Replies", tint: .green)
        replies.clipIDs = [clips[0].id, clips[11].id]

        let snippets = [
            Snippet(name: "Email", trigger: ";;mail", content: "hello@superclip.app"),
            Snippet(name: "Thanks", trigger: ";;ty", content: "Thanks so much. Really appreciate it."),
            Snippet(name: "Address", trigger: ";;addr", content: "4 Privet Drive, Little Whinging, Surrey"),
        ]
        return (clips, [brand, reading, replies], snippets)
    }

    private static func sampleImage() -> UIImage {
        let size = CGSize(width: 1200, height: 750)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [UIColor(red: 0.36, green: 0.82, blue: 0.86, alpha: 1).cgColor, UIColor(red: 0.43, green: 0.47, blue: 0.96, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            UIColor.white.withAlphaComponent(0.92).setFill()
            context.fill(CGRect(x: 96, y: 520, width: 520, height: 44))
            context.fill(CGRect(x: 96, y: 592, width: 340, height: 44))
        }
    }
}
