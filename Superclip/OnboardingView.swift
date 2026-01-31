//
//  OnboardingView.swift
//  Superclip
//

import AppKit
import ApplicationServices
import SwiftUI

// MARK: - Design Tokens (matching website)

private enum OB {
    static let bg = Color(red: 0.02, green: 0.02, blue: 0.027)
    static let fg = Color(red: 0.94, green: 0.94, blue: 0.96)
    static let fgMuted = Color(red: 0.94, green: 0.94, blue: 0.96).opacity(0.55)
    static let fgSubtle = Color(red: 0.94, green: 0.94, blue: 0.96).opacity(0.3)
    static let cyan = Color(red: 0, green: 0.83, blue: 1)
    static let purple = Color(red: 0.545, green: 0.36, blue: 0.965)
    static let emerald = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let pink = Color(red: 0.925, green: 0.286, blue: 0.6)
    static let orange = Color(red: 0.961, green: 0.62, blue: 0.043)
    static let glassBg = Color.white.opacity(0.04)
    static let glassBorder = Color.white.opacity(0.08)
    static let glassHover = Color.white.opacity(0.07)
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
                        Capsule()
                            .fill(index == currentPage
                                  ? AnyShapeStyle(LinearGradient(colors: [OB.cyan, OB.purple], startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.white.opacity(0.15)))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
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
                .frame(height: 440)
                .clipped()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer(minLength: 0)

                // Bottom button — pinned
                GradientButton(
                    title: currentPage == 2 ? "Get Started" : continueLabel,
                    action: currentPage == 2 ? onComplete : advance
                )
                .padding(.horizontal, 48)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 520, height: 600)
        .preferredColorScheme(.dark)
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
        ZStack {
            // Cyan blob — top right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [OB.cyan.opacity(0.12), OB.cyan.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: page == 0 ? 140 : (page == 1 ? 60 : 100),
                        y: page == 0 ? -160 : (page == 1 ? -100 : -140))
                .animation(.easeInOut(duration: 1.0), value: page)

            // Purple blob — bottom left
            Circle()
                .fill(
                    RadialGradient(
                        colors: [OB.purple.opacity(0.1), OB.purple.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: page == 0 ? -120 : (page == 1 ? -80 : -100),
                        y: page == 0 ? 140 : (page == 1 ? 100 : 120))
                .animation(.easeInOut(duration: 1.0), value: page)
        }
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
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [OB.cyan, OB.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: OB.cyan.opacity(isHovered ? 0.4 : 0.25), radius: isHovered ? 24 : 16, y: 4)
                        .shadow(color: OB.purple.opacity(isHovered ? 0.2 : 0.12), radius: isHovered ? 32 : 24, y: 8)
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.easeOut(duration: 0.2), value: isHovered)
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
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(OB.glassBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(OB.glassBorder, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // App icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [OB.cyan.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            }

            VStack(spacing: 10) {
                Text("Your clipboard, \(Text("supercharged.").foregroundColor(OB.cyan))")
                    .font(.system(size: 28, weight: .bold))

                Text("Everything you copy, organized and ready to use.")
                    .font(.system(size: 14))
                    .foregroundStyle(OB.fgMuted)
            }

            VStack(spacing: 10) {
                FeatureRow(
                    icon: "clock.arrow.circlepath",
                    title: "Clipboard History",
                    subtitle: "Every copy saved and searchable",
                    gradient: [OB.cyan, OB.purple]
                )
                FeatureRow(
                    icon: "pin.fill",
                    title: "Pinboards",
                    subtitle: "Color-coded boards for your favorites",
                    gradient: [OB.purple, OB.pink]
                )
                FeatureRow(
                    icon: "text.viewfinder",
                    title: "Text Sniper",
                    subtitle: "Extract text from anywhere on screen",
                    gradient: [OB.pink, OB.orange]
                )
            }
            .padding(.horizontal, 36)

            Spacer()
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                // Gradient icon box
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
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
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [OB.purple.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [OB.cyan, OB.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

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

            Spacer()
        }
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
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    private func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isGranted
                              ? LinearGradient(colors: [OB.emerald, OB.emerald.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)

                    Image(systemName: isGranted ? "checkmark" : "lock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isGranted ? .white : Color.white.opacity(0.4))
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
                                .foregroundColor(OB.orange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(OB.orange.opacity(0.12))
                                        .overlay(Capsule().stroke(OB.orange.opacity(0.2), lineWidth: 1))
                                )
                        } else {
                            Text("Optional")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(OB.fgSubtle)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
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
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(isHovered ? 0.12 : 0.08))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in isHovered = h }
                } else {
                    Text("Granted")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(OB.emerald)
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
            Spacer()

            // Success icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [OB.emerald.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [OB.emerald, OB.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: 10) {
                Text("You\u{2019}re all set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(OB.fg)

                Text("Here are the shortcuts you\u{2019}ll use most:")
                    .font(.system(size: 14))
                    .foregroundStyle(OB.fgMuted)
            }

            VStack(spacing: 8) {
                ShortcutRow(keys: "\u{2318}\u{21E7}A", label: "Open clipboard history", glow: true)
                ShortcutRow(keys: "\u{2318}\u{21E7}C", label: "Copy & open paste stack", glow: false)
                ShortcutRow(keys: "\u{2318}\u{21E7}`", label: "Text Sniper (screen OCR)", glow: false)
            }
            .padding(.horizontal, 36)

            Spacer()
        }
    }
}

private struct ShortcutRow: View {
    let keys: String
    let label: String
    let glow: Bool

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Text(keys)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(glow ? OB.cyan.opacity(0.9) : Color.white.opacity(0.6))
                    .frame(width: 64, alignment: .center)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(glow ? OB.cyan.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: glow ? OB.cyan.opacity(0.12) : Color.clear, radius: 8)
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
