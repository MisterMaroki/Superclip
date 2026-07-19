//
//  OnboardingView.swift
//  Superclip
//

import AppKit
import ApplicationServices
import SwiftUI

// MARK: - Design Tokens (matching website)

private enum OB {
    static let bg = Brand.white
    static let fg = Brand.black
    static let fgMuted = Brand.gray500
    static let fgSubtle = Brand.gray500
    static let glassBg = Brand.white
    static let glassBorder = Brand.gray200
}

// MARK: - Main View

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        ZStack {
            // Background
            OB.bg.ignoresSafeArea()

            // Gradient blobs
            GradientBlobs(page: currentPage)

            VStack(spacing: 0) {
                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Rectangle()
                            .fill(index == currentPage
                                  ? AnyShapeStyle(Brand.black)
                                  : AnyShapeStyle(Brand.gray200))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 36)
                .padding(.bottom, 20)

                // Page content — fixed height so the button never moves
                ZStack {
                    switch currentPage {
                    case 0:
                        WelcomePage()
                    case 1:
                        PermissionsPage()
                    default:
                        ReadyPage()
                    }
                }
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                // Bottom button
                GradientButton(
                    title: currentPage == 2 ? "Get Started" : continueLabel,
                    action: currentPage == 2 ? onComplete : advance
                )
                .padding(.horizontal, 48)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 520)
    }

    private var continueLabel: String {
        if currentPage == 1 {
            let accessOK = AXIsProcessTrusted()
            let screenOK = CGPreflightScreenCaptureAccess()
            if !accessOK && !screenOK {
                return "Continue Without Permissions"
            }
        }
        return "Continue"
    }

    private func advance() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentPage += 1
        }
    }
}

// MARK: - Gradient Background Blobs

private struct GradientBlobs: View {
    let page: Int

    var body: some View {
        EmptyView()
    }
}

// MARK: - Gradient Button

private struct GradientButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Brand.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    Rectangle()
                        .fill(Brand.black)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Glass Card

private struct GlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(
                Rectangle()
                    .fill(Brand.white)
                    .overlay(
                        Rectangle()
                            .stroke(Brand.gray200, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 28) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(Rectangle())

            VStack(spacing: 10) {
                Text("Your clipboard, \(Text("supercharged.").fontWeight(.black))")
                    .font(.system(size: 28, weight: .bold))

                Text("Everything you copy, organized and ready to use.")
                    .font(.system(size: 14))
                    .foregroundStyle(OB.fgMuted)
            }

            VStack(spacing: 8) {
                FeatureRow(
                    icon: "clock.arrow.circlepath",
                    title: "Clipboard History",
                    subtitle: "Every copy saved and searchable"
                )
                FeatureRow(
                    icon: "pin.fill",
                    title: "Pinboards",
                    subtitle: "Color-coded boards for your favorites"
                )
                FeatureRow(
                    icon: "text.cursor",
                    title: "Snippets",
                    subtitle: "Type a trigger, expand into full text"
                )
                FeatureRow(
                    icon: "bolt.fill",
                    title: "Quick Actions",
                    subtitle: "Convert colors, format JSON, and more"
                )
                FeatureRow(
                    icon: "text.viewfinder",
                    title: "Text Sniper",
                    subtitle: "Extract text from anywhere on screen"
                )
            }
            .padding(.horizontal, 36)
        }
        .padding(.vertical, 32)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                // Icon box
                ZStack {
                    Rectangle()
                        .fill(Brand.black)
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Brand.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(OB.fg)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(OB.fgMuted)
                }

                Spacer()
            }
            .padding(14)
        }
    }
}

// MARK: - Page 2: Permissions

private struct PermissionsPage: View {
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var screenRecordingGranted = CGPreflightScreenCaptureAccess()
    @State private var pollTimer: Timer?

    var body: some View {
        VStack(spacing: 28) {
            // Icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Brand.black)

            VStack(spacing: 10) {
                Text("Quick permissions")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(OB.fg)

                Text("Superclip needs a couple of things\nto work its magic.")
                    .font(.system(size: 14))
                    .foregroundStyle(OB.fgMuted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                PermissionRow(
                    title: "Accessibility",
                    subtitle: "Global hotkeys and paste simulation",
                    isGranted: accessibilityGranted,
                    isRequired: true,
                    action: requestAccessibility
                )

                PermissionRow(
                    title: "Screen Recording",
                    subtitle: "Enables Text Sniper (OCR)",
                    isGranted: screenRecordingGranted,
                    isRequired: false,
                    action: requestScreenRecording
                )
            }
            .padding(.horizontal, 36)
        }
        .padding(.vertical, 32)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            DispatchQueue.main.async {
                accessibilityGranted = AXIsProcessTrusted()
                screenRecordingGranted = CGPreflightScreenCaptureAccess()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func requestAccessibility() {
        // Register the app in the accessibility list
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        // Open Settings after a brief delay so the app appears in the list
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !AXIsProcessTrusted(),
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !CGPreflightScreenCaptureAccess(),
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let subtitle: String
    let isGranted: Bool
    let isRequired: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                // Status icon
                ZStack {
                    Rectangle()
                        .fill(isGranted ? Brand.black : Brand.gray200)
                        .frame(width: 36, height: 36)

                    Image(systemName: isGranted ? "checkmark" : "lock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isGranted ? Brand.white : Brand.gray500)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isGranted)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(OB.fg)

                        if isRequired {
                            Text("Required")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Brand.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Rectangle()
                                        .fill(Brand.gray100)
                                        .overlay(Rectangle().stroke(Brand.gray200, lineWidth: 1))
                                )
                        } else {
                            Text("Optional")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(OB.fgSubtle)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Rectangle()
                                        .fill(Brand.gray100)
                                        .overlay(Rectangle().stroke(Brand.gray200, lineWidth: 1))
                                )
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(OB.fgMuted)
                }

                Spacer()

                if !isGranted {
                    Button(action: action) {
                        Text("Grant")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Brand.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Rectangle()
                                    .fill(Brand.gray100)
                                    .overlay(Rectangle().stroke(Brand.gray200, lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in isHovered = h }
                } else {
                    Text("Granted")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Brand.black)
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Page 3: Ready

private struct ReadyPage: View {
    var body: some View {
        VStack(spacing: 28) {
            // Success icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Brand.black)

            VStack(spacing: 10) {
                Text("You\u{2019}re all set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(OB.fg)

                Text("Here are the shortcuts you\u{2019}ll use most:")
                    .font(.system(size: 14))
                    .foregroundStyle(OB.fgMuted)
            }

            VStack(spacing: 8) {
                ShortcutRow(keys: "\u{2318}\u{21E7}A", label: "Open clipboard history")
                ShortcutRow(keys: "\u{2318}\u{21E7}C", label: "Copy & open paste stack")
                ShortcutRow(keys: "\u{2318}\u{21E7}`", label: "Text Sniper (screen OCR)")
            }
            .padding(.horizontal, 36)
        }
        .padding(.vertical, 32)
    }
}

private struct ShortcutRow: View {
    let keys: String
    let label: String

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Text(keys)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Brand.black)
                    .frame(width: 64, alignment: .center)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        Rectangle()
                            .fill(Brand.gray100)
                            .overlay(
                                Rectangle()
                                    .stroke(Brand.gray200, lineWidth: 1)
                            )
                    )

                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(OB.fgMuted)

                Spacer()
            }
            .padding(12)
        }
    }
}
