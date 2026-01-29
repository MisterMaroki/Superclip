//
//  OnboardingView.swift
//  Superclip
//

import AppKit
import SwiftUI

// MARK: - Onboarding Data

struct OnboardingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

private let features: [OnboardingFeature] = [
    OnboardingFeature(
        icon: "doc.on.clipboard.fill",
        title: "Clipboard History",
        description: "Everything you copy is saved automatically. Open the drawer anytime with ⌘⇧A to find and reuse past clips.",
        color: .blue
    ),
    OnboardingFeature(
        icon: "pin.fill",
        title: "Pinboards",
        description: "Drag items to pinboards to organize your favorites. Create boards for code snippets, links, or anything you reuse often.",
        color: .orange
    ),
    OnboardingFeature(
        icon: "text.viewfinder",
        title: "Text Sniper",
        description: "Press ⌘⇧` to capture text from anywhere on screen — images, videos, non-selectable text. It just works.",
        color: .purple
    ),
    OnboardingFeature(
        icon: "square.stack.fill",
        title: "Paste Stack",
        description: "Copy multiple items, then paste them in sequence. Press ⌘⇧C to start a paste stack session.",
        color: .green
    ),
]

// MARK: - Onboarding View

struct OnboardingView: View {
    @State private var currentPage: Int = 0
    @State private var accessibilityGranted: Bool = false
    @State private var screenRecordingGranted: Bool = false
    @State private var permissionCheckTimer: Timer?

    var onComplete: () -> Void

    private let totalPages = 3 // Welcome, Features, Permissions & Finish

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch currentPage {
                case 0:
                    welcomePage
                case 1:
                    featuresPage
                case 2:
                    permissionsPage
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(currentPage)

            // Footer with navigation
            footerView
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(width: 560, height: 520)
        .background(
            ZStack {
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                Color(nsColor: .windowBackgroundColor).opacity(0.3)
            }
        )
        .onAppear {
            checkPermissions()
        }
        .onDisappear {
            permissionCheckTimer?.invalidate()
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)

            VStack(spacing: 12) {
                Text("Welcome to Superclip")
                    .font(.system(size: 28, weight: .bold))

                Text("Your clipboard, supercharged. Superclip lives in your menu bar and remembers everything you copy.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 400)
            }

            // Hotkey callout
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    KeyCapView(text: "⌘")
                    KeyCapView(text: "⇧")
                    KeyCapView(text: "A")
                }
                Text("opens Superclip from anywhere")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Page 2: Features

    private var featuresPage: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 12)

            Text("What you can do")
                .font(.system(size: 22, weight: .bold))

            VStack(spacing: 16) {
                ForEach(features) { feature in
                    FeatureRow(feature: feature)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Page 3: Permissions & Finish

    private var permissionsPage: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 12)

            VStack(spacing: 8) {
                Text("Almost ready")
                    .font(.system(size: 22, weight: .bold))

                Text("Superclip needs a couple of permissions to work its magic.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            VStack(spacing: 12) {
                PermissionRow(
                    icon: "keyboard.fill",
                    title: "Accessibility",
                    description: "Required for global hotkeys (⌘⇧A) to work from any app.",
                    isGranted: accessibilityGranted,
                    action: requestAccessibility
                )

                PermissionRow(
                    icon: "camera.metering.spot",
                    title: "Screen Recording",
                    description: "Optional. Enables Text Sniper to capture text from your screen.",
                    isGranted: screenRecordingGranted,
                    isOptional: true,
                    action: requestScreenRecording
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Reassurance note
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Superclip never sends your data anywhere. Everything stays on your Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Footer Navigation

    private var footerView: some View {
        HStack {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { page in
                    Circle()
                        .fill(page == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                if currentPage < totalPages - 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    } label: {
                        Text("Continue")
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button {
                        onComplete()
                    } label: {
                        Text("Get Started")
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    // MARK: - Permissions

    private func checkPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()

        // Poll for permission changes while onboarding is visible
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                let newAccessibility = AXIsProcessTrusted()
                let newScreenRecording = CGPreflightScreenCaptureAccess()
                if newAccessibility != accessibilityGranted {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        accessibilityGranted = newAccessibility
                    }
                }
                if newScreenRecording != screenRecordingGranted {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        screenRecordingGranted = newScreenRecording
                    }
                }
            }
        }
    }

    private func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    private func requestScreenRecording() {
        // Trigger the system prompt
        CGRequestScreenCaptureAccess()
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let feature: OnboardingFeature

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.system(size: 22))
                .foregroundStyle(feature.color)
                .frame(width: 44, height: 44)
                .background(feature.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(feature.description)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    var isOptional: Bool = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isGranted ? .green : .secondary)
                .frame(width: 40, height: 40)
                .background(
                    (isGranted ? Color.green : Color.secondary).opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    if isOptional {
                        Text("Optional")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isGranted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isGranted)
    }
}

// MARK: - Key Cap View (keyboard shortcut visual)

struct KeyCapView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .frame(minWidth: 32, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
}
