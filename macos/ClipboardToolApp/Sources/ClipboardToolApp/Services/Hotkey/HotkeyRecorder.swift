import AppKit
import Carbon
import SwiftUI

/// Captures a single key combo from the user.
struct HotkeyRecorder: View {
    @Environment(\.dismiss) private var dismiss

    let onRecorded: (_ keyCode: UInt32, _ carbonModifiers: UInt32, _ display: String) -> Void

    @State private var monitor: Any?
    @State private var statusText: String = "Press the desired key combination…"

    var body: some View {
        VStack(spacing: 12) {
            Text("Record Hotkey")
                .font(.headline)

            Text(statusText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            startMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        stopMonitoring()

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Ignore pure modifier presses.
            if event.keyCode == 55 || event.keyCode == 54 || event.keyCode == 56 || event.keyCode == 60 || event.keyCode == 58 || event.keyCode == 61 || event.keyCode == 59 || event.keyCode == 62 {
                return nil
            }

            let (mods, displayMods) = Self.carbonModifiers(from: event.modifierFlags)
            if mods == 0 {
                self.statusText = "Please include at least one modifier (⌘/⌥/⌃/⇧)."
                return nil
            }

            let keyCode = UInt32(event.keyCode)
            let keyName = Self.keyName(for: event)
            let display = (displayMods + [keyName]).joined(separator: " ")

            onRecorded(keyCode, mods, display)
            dismiss()
            return nil
        }
    }

    private func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> (UInt32, [String]) {
        var mods: UInt32 = 0
        var display: [String] = []

        if flags.contains(.command) {
            mods |= UInt32(cmdKey)
            display.append("⌘")
        }
        if flags.contains(.option) {
            mods |= UInt32(optionKey)
            display.append("⌥")
        }
        if flags.contains(.control) {
            mods |= UInt32(controlKey)
            display.append("⌃")
        }
        if flags.contains(.shift) {
            mods |= UInt32(shiftKey)
            display.append("⇧")
        }
        return (mods, display)
    }

    static func keyName(for event: NSEvent) -> String {
        // Prefer charactersIgnoringModifiers for readable keys.
        if let s = event.charactersIgnoringModifiers, !s.isEmpty {
            let upper = s.uppercased()
            if upper == " " { return "Space" }
            if upper == "\r" { return "Enter" }
            if upper == "\u{1b}" { return "Esc" }
            if upper == "\t" { return "Tab" }
            return upper
        }
        return "KeyCode(\(event.keyCode))"
    }
}
