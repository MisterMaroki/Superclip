//
//  OnboardingView.swift
//  Superclip
//
//  First-run setup assistant. Three short steps, laid out like a macOS setup
//  sheet: a step rail on the left tracks progress, the right pane does the work.
//
//    1. Permissions – grant Accessibility (required) and Screen Recording.
//    2. Shortcut    – the user presses ⌘⇧A for real; the drawer opens.
//    3. Done        – the remaining shortcuts and where to find the app.
//

import AppKit
import ApplicationServices
import SwiftUI

// MARK: - Layout constants

enum OnboardingLayout {
    static let windowSize = CGSize(width: 760, height: 480)
    static let railWidth: CGFloat = 236
}

private enum Step: Int, CaseIterable {
    case permissions, shortcut, done

    var title: String {
        switch self {
        case .permissions: return "Permissions"
        case .shortcut: return "Your shortcut"
        case .done: return "All set"
        }
    }

    var railSubtitle: String {
        switch self {
        case .permissions: return "Let Superclip paste for you"
        case .shortcut: return "Learn the one that matters"
        case .done: return "Everything else"
        }
    }
}

// MARK: - Main View

struct OnboardingView: View {
    @ObservedObject var settings: SettingsManager
    var onComplete: () -> Void

    @State private var step: Step = .permissions
    @State private var hotkeyConfirmed = false
    // Owned here (not by the step) so the footer button tracks the live status.
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var openAtLogin: Bool

    /// - Parameter initialStep: 0-based step to open on (used to render each
    ///   step for review; the app always starts at the first).
    init(settings: SettingsManager, initialStep: Int = 0, onComplete: @escaping () -> Void) {
        self.settings = settings
        self.onComplete = onComplete
        _step = State(initialValue: Step(rawValue: initialStep) ?? .permissions)
        // First run: offer it pre-checked. Re-running the guide: show the real state.
        let isFirstRun = !UserDefaults.standard.bool(forKey: WelcomeWindowController.hasSeenWelcomeKey)
        _openAtLogin = State(initialValue: isFirstRun ? true : settings.launchAtLogin)
    }

    private var historyHotkey: HotkeyConfig { settings.hotkeyConfigForHistory() }

    var body: some View {
        HStack(spacing: 0) {
            StepRail(current: step, hotkeyConfirmed: hotkeyConfirmed)
                .frame(width: OnboardingLayout.railWidth)

            Rectangle()
                .fill(Brand.gray200)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    switch step {
                    case .permissions:
                        PermissionsStep(accessibilityGranted: $accessibilityGranted)
                    case .shortcut:
                        ShortcutStep(confirmed: $hotkeyConfirmed, keys: historyHotkey.keyCaps)
                    case .done:
                        DoneStep(settings: settings)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 44)
                .padding(.horizontal, 44)
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))

                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Brand.white)
        }
        .frame(width: OnboardingLayout.windowSize.width, height: OnboardingLayout.windowSize.height)
        .background(Brand.white)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .permissions {
                GhostButton(title: "Back") { move(-1) }
            }

            Spacer()

            if step == .done {
                CheckboxRow(title: "Open Superclip at login", isOn: $openAtLogin)
            }

            if step == .shortcut && !hotkeyConfirmed {
                GhostButton(title: "Skip for now") { move(1) }
            }

            PrimaryButton(
                title: primaryTitle,
                isEnabled: !(step == .shortcut && !hotkeyConfirmed),
                action: primaryAction)
        }
        .padding(.horizontal, 44)
        .padding(.bottom, 32)
        .padding(.top, 16)
    }

    private var primaryTitle: String {
        switch step {
        case .permissions:
            return accessibilityGranted ? "Continue" : "Continue anyway"
        case .shortcut:
            return hotkeyConfirmed ? "Continue" : "Waiting for \(historyHotkey.keyCaps.joined())\u{2026}"
        case .done:
            return "Finish"
        }
    }

    private func primaryAction() {
        switch step {
        case .permissions:
            move(1)
        case .shortcut:
            if hotkeyConfirmed { move(1) }
        case .done:
            if settings.launchAtLogin != openAtLogin {
                settings.launchAtLogin = openAtLogin
            }
            onComplete()
        }
    }

    private func move(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        step = next
    }
}

// MARK: - Step rail

private struct StepRail: View {
    let current: Step
    let hotkeyConfirmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Superclip")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Brand.black)
                    Text("Setup")
                        .font(.system(size: 12))
                        .foregroundStyle(Brand.gray500)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 44)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Step.allCases.enumerated()), id: \.element) { index, step in
                    RailRow(
                        index: index + 1,
                        step: step,
                        state: state(for: step),
                        isLast: index == Step.allCases.count - 1
                    )
                }
            }

            Spacer()

            Text("You can change any of this later in Settings.")
                .font(.system(size: 11))
                .foregroundStyle(Brand.gray500)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 28)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Brand.gray100)
    }

    private func state(for step: Step) -> RailRow.State {
        if step.rawValue < current.rawValue { return .done }
        if step == current { return .current }
        return .upcoming
    }
}

private struct RailRow: View {
    enum State { case done, current, upcoming }

    let index: Int
    let step: Step
    let state: State
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(state == .upcoming ? Brand.white : Brand.black)
                        .overlay(Rectangle().stroke(state == .upcoming ? Brand.gray300 : Brand.black, lineWidth: 1))
                        .frame(width: 26, height: 26)

                    if state == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Brand.white)
                    } else {
                        Text("\(index)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(state == .current ? Brand.white : Brand.gray500)
                    }
                }

                if !isLast {
                    Rectangle()
                        .fill(state == .done ? Brand.black : Brand.gray300)
                        .frame(width: 1, height: 34)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.system(size: 13, weight: state == .current ? .semibold : .medium))
                    .foregroundColor(state == .upcoming ? Brand.gray500 : Brand.black)
                Text(step.railSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Brand.gray500)
                    .opacity(state == .current ? 1 : 0.7)
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.25), value: state == .done)
    }
}

// MARK: - Shared pieces

private struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Brand.black)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Brand.gray500)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isEnabled ? Brand.white : Brand.gray500)
                .padding(.horizontal, 22)
                .frame(height: 38)
                .background(Rectangle().fill(isEnabled ? Brand.black : Brand.gray200))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .keyboardShortcut(.defaultAction)
    }
}

private struct GhostButton: View {
    let title: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(hovered ? Brand.black : Brand.gray500)
                .padding(.horizontal, 14)
                .frame(height: 38)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct CheckboxRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Rectangle()
                        .fill(isOn ? Brand.black : Brand.white)
                        .overlay(Rectangle().stroke(isOn ? Brand.black : Brand.gray300, lineWidth: 1))
                        .frame(width: 16, height: 16)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Brand.white)
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Brand.gray600)
            }
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .padding(.trailing, 8)
    }
}

private struct KeyCap: View {
    let symbol: String
    let size: CGFloat

    init(_ symbol: String, size: CGFloat = 56) {
        self.symbol = symbol
        self.size = size
    }

    var body: some View {
        Text(symbol)
            .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
            .foregroundColor(Brand.black)
            .frame(width: size, height: size)
            .background(
                Rectangle()
                    .fill(Brand.white)
                    .overlay(Rectangle().stroke(Brand.gray300, lineWidth: 1))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Brand.gray300).frame(height: 3)
                    }
            )
    }
}

private struct KeyCombo: View {
    let keys: [String]
    let size: CGFloat

    init(_ keys: [String], size: CGFloat = 56) {
        self.keys = keys
        self.size = size
    }

    var body: some View {
        HStack(spacing: size * 0.14) {
            ForEach(keys, id: \.self) { KeyCap($0, size: size) }
        }
    }
}

// MARK: - Step 1: Permissions

private struct PermissionsStep: View {
    @Binding var accessibilityGranted: Bool
    @State private var screenRecordingGranted = CGPreflightScreenCaptureAccess()
    @State private var pollTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepHeader(
                title: "Two quick permissions",
                subtitle: "Superclip runs in the background and works inside every app. macOS needs you to allow that explicitly."
            )

            VStack(spacing: 0) {
                PermissionRow(
                    title: "Accessibility",
                    detail: "Paste into other apps and expand snippets as you type.",
                    badge: "Required",
                    isGranted: accessibilityGranted,
                    action: requestAccessibility
                )
                Rectangle().fill(Brand.gray200).frame(height: 1)
                PermissionRow(
                    title: "Screen Recording",
                    detail: "Take screenshots and grab text from the screen.",
                    badge: "Optional",
                    isGranted: screenRecordingGranted,
                    action: requestScreenRecording
                )
            }
            .overlay(Rectangle().stroke(Brand.gray200, lineWidth: 1))

            Text("Granting opens System Settings. Come back here when you\u{2019}re done \u{2014} this list updates by itself. Screen Recording may only show as granted after Superclip restarts.")
                .font(.system(size: 12))
                .foregroundStyle(Brand.gray500)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
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
    let detail: String
    let badge: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Rectangle()
                    .fill(isGranted ? Brand.black : Brand.gray100)
                    .frame(width: 32, height: 32)
                Image(systemName: isGranted ? "checkmark" : "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isGranted ? Brand.white : Brand.gray500)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isGranted)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Brand.black)
                    Text(badge.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Brand.gray500)
                }
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.gray500)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if isGranted {
                Text("Granted")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Brand.gray500)
            } else {
                Button(action: action) {
                    Text("Grant\u{2026}")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Brand.black)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(
                            Rectangle()
                                .fill(Brand.white)
                                .overlay(Rectangle().stroke(Brand.gray300, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }
}

// MARK: - Step 2: Shortcut

/// Waits for the user to press the real global hotkey. While onboarding is on
/// screen, AppDelegate posts `.onboardingHotkeyPressed` and opens the drawer.
private struct ShortcutStep: View {
    @Binding var confirmed: Bool
    let keys: [String]
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepHeader(
                title: confirmed ? "That\u{2019}s your clipboard." : "Press this now",
                subtitle: confirmed
                    ? "The drawer just opened at the bottom of your screen. Press the shortcut again any time, in any app \u{2014} or click the paperclip in your menu bar."
                    : "This is the only shortcut you need to remember. It opens your clipboard history from anywhere."
            )

            HStack(spacing: 20) {
                KeyCombo(keys, size: 64)
                    .scaleEffect(pulse && !confirmed ? 1.03 : 1)
                    .opacity(confirmed ? 0.55 : 1)

                if confirmed {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Got it")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Brand.black)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .padding(.vertical, 8)

            if !confirmed {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("Nothing happening? Click the paperclip icon in your menu bar instead.")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Brand.gray500)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: confirmed)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingHotkeyPressed)) { _ in
            confirmed = true
        }
    }
}

extension Notification.Name {
    /// Posted when the history hotkey fires while onboarding is on screen.
    static let onboardingHotkeyPressed = Notification.Name("Superclip.onboardingHotkeyPressed")
    /// Posted by Settings / the menu bar to re-open the setup guide.
    static let superclipShowSetupGuide = Notification.Name("Superclip.showSetupGuide")
    /// Posted by Settings to run the real (Sparkle) update check.
    static let superclipCheckForUpdates = Notification.Name("Superclip.checkForUpdates")
}

// MARK: - Step 3: Done

private struct DoneStep: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StepHeader(
                title: "You\u{2019}re set",
                subtitle: "Superclip is already saving everything you copy. Three more shortcuts when you want them:"
            )

            VStack(spacing: 0) {
                ShortcutRow(keys: settings.hotkeyConfigForPasteStack().keyCaps, title: "Paste stack", detail: "Copy several things, then paste them one after another.")
                Rectangle().fill(Brand.gray200).frame(height: 1)
                ShortcutRow(keys: settings.hotkeyConfigForScreenshot().keyCaps, title: "Screenshot", detail: "Capture an area, window or the full screen, then annotate and copy.")
                Rectangle().fill(Brand.gray200).frame(height: 1)
                ShortcutRow(keys: settings.hotkeyConfigForOCR().keyCaps, title: "Text Sniper", detail: "Select any area of the screen and copy the text in it.")
            }
            .overlay(Rectangle().stroke(Brand.gray200, lineWidth: 1))

            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                    .font(.system(size: 12, weight: .semibold))
                Text("Superclip lives in the menu bar. Settings and Quit are there.")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Brand.gray500)
        }
    }
}

private struct ShortcutRow: View {
    let keys: [String]
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 16) {
            KeyCombo(keys, size: 28)
                .frame(minWidth: 104, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.black)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.gray500)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
