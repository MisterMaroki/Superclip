//
//  HotkeyRecorderView.swift
//  Superclip
//

import SwiftUI
import AppKit
import Carbon
import HotKey

// MARK: - Hotkey Configuration Model

struct HotkeyConfig: Equatable {
    var carbonKeyCode: UInt32
    var carbonModifiers: UInt32

    var keyCombo: KeyCombo {
        KeyCombo(carbonKeyCode: carbonKeyCode, carbonModifiers: carbonModifiers)
    }

    var key: Key? {
        Key(carbonKeyCode: carbonKeyCode)
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(carbonFlags: carbonModifiers)
    }

    var displayString: String {
        keyCombo.description
    }

    var isValid: Bool {
        // Must have at least one modifier (Cmd, Ctrl, Option)
        // Shift alone is not sufficient
        let mods = modifiers
        let hasMainModifier = mods.contains(.command) || mods.contains(.control) || mods.contains(.option)
        return hasMainModifier && key != nil
    }

    // Default hotkeys
    static let defaultHistory = HotkeyConfig(carbonKeyCode: UInt32(kVK_ANSI_A), carbonModifiers: NSEvent.ModifierFlags([.command, .shift]).carbonFlags)
    static let defaultPasteStack = HotkeyConfig(carbonKeyCode: UInt32(kVK_ANSI_C), carbonModifiers: NSEvent.ModifierFlags([.command, .shift]).carbonFlags)
    static let defaultOCR = HotkeyConfig(carbonKeyCode: UInt32(kVK_ANSI_Grave), carbonModifiers: NSEvent.ModifierFlags([.command, .shift]).carbonFlags)

    // UserDefaults serialization
    var dictionary: [String: Int] {
        ["keyCode": Int(carbonKeyCode), "modifiers": Int(carbonModifiers)]
    }

    init(carbonKeyCode: UInt32, carbonModifiers: UInt32) {
        self.carbonKeyCode = carbonKeyCode
        self.carbonModifiers = carbonModifiers
    }

    init?(dictionary: [String: Int]) {
        guard let keyCode = dictionary["keyCode"],
              let modifiers = dictionary["modifiers"] else { return nil }
        self.carbonKeyCode = UInt32(keyCode)
        self.carbonModifiers = UInt32(modifiers)
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    let title: String
    @Binding var config: HotkeyConfig
    let allConfigs: [HotkeyConfig]  // All hotkey configs for conflict detection
    let onChanged: () -> Void

    @State private var isRecording = false
    @State private var errorMessage: String?
    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.95))

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }

            Spacer()

            Button {
                isRecording.toggle()
                if !isRecording {
                    errorMessage = nil
                }
            } label: {
                Text(isRecording ? "Press shortcut..." : config.displayString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(isRecording ? .orange : .primary.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(minWidth: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? Color.orange.opacity(0.1) : Color.primary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.orange.opacity(0.5) : (isHovered ? Color.primary.opacity(0.2) : Color.primary.opacity(0.12)), lineWidth: 1)
                    )
                    .animation(.easeInOut(duration: 0.15), value: isRecording)
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHovered = hovering }
            .background(
                // Hidden key event capture when recording
                HotkeyCapture(isRecording: $isRecording, onCapture: handleCapture)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func handleCapture(_ keyCode: UInt16, _ modifierFlags: NSEvent.ModifierFlags) {
        // Filter to only relevant modifiers
        let cleanMods = modifierFlags.intersection([.command, .control, .option, .shift])

        let newConfig = HotkeyConfig(
            carbonKeyCode: UInt32(keyCode),
            carbonModifiers: cleanMods.carbonFlags
        )

        // Validate: needs at least one main modifier
        if !newConfig.isValid {
            errorMessage = "Add a modifier key (⌘, ⌃, or ⌥)"
            return
        }

        // Check for conflicts with other hotkeys
        for other in allConfigs where other != config {
            if other.carbonKeyCode == newConfig.carbonKeyCode && other.carbonModifiers == newConfig.carbonModifiers {
                errorMessage = "Conflicts with another shortcut"
                return
            }
        }

        // Apply
        errorMessage = nil
        config = newConfig
        isRecording = false
        onChanged()
    }
}

// MARK: - NSView-based Key Capture

struct HotkeyCapture: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> HotkeyCaptureNSView {
        let view = HotkeyCaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: HotkeyCaptureNSView, context: Context) {
        nsView.isRecordingActive = isRecording
        nsView.onCapture = onCapture
        if isRecording {
            // Use a local event monitor to capture key events when recording
            nsView.startMonitoring()
        } else {
            nsView.stopMonitoring()
        }
    }
}

class HotkeyCaptureNSView: NSView {
    var isRecordingActive = false
    var onCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    private var monitor: Any?

    func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecordingActive else { return event }

            // Escape cancels recording
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    self.isRecordingActive = false
                }
                return nil
            }

            // Ignore bare modifier keys (they'll be captured with the actual key)
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63] // Cmd, Shift, Caps, Option, Control variants
            if modifierKeyCodes.contains(event.keyCode) {
                return nil
            }

            self.onCapture?(event.keyCode, event.modifierFlags)
            return nil  // Consume the event
        }
    }

    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        stopMonitoring()
    }
}
