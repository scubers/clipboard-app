import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case preview = "Preview"
    case storage = "Storage"
    case shortcuts = "Shortcuts"
    case capture = "Capture"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .preview: return "eye"
        case .storage: return "folder"
        case .shortcuts: return "keyboard"
        case .capture: return "tray.and.arrow.down"
        case .advanced: return "wrench.and.screwdriver"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Common app behavior and startup."
        case .appearance: return "Readability and visual tuning."
        case .preview: return "Text rendering options for preview pane."
        case .storage: return "Where the app stores shared data."
        case .shortcuts: return "Keyboard shortcuts and hotkeys."
        case .capture: return "Control what gets captured and retained."
        case .advanced: return "Maintenance and data tools."
        }
    }
}

@MainActor
final class HotkeyCapture: ObservableObject {
    @Published var status: String = "Press keys now"

    private var monitor: Any?

    func start(onCaptured: @escaping (_ keyCode: UInt32, _ carbonModifiers: UInt32, _ display: String) -> Void, onCancel: @escaping () -> Void) {
        stop()

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }

            // Esc to cancel
            if event.keyCode == 53 {
                onCancel()
                return nil
            }

            // Backspace to clear
            if event.keyCode == 51 {
                onCaptured(0, 0, "")
                return nil
            }

            // Ignore pure modifier presses.
            if event.keyCode == 55 || event.keyCode == 54 || event.keyCode == 56 || event.keyCode == 60 || event.keyCode == 58 || event.keyCode == 61 || event.keyCode == 59 || event.keyCode == 62 {
                return nil
            }

            let (mods, displayMods) = HotkeyRecorder.carbonModifiers(from: event.modifierFlags)
            if mods == 0 {
                self.status = "Please include at least one modifier (⌘/⌥/⌃/⇧)."
                return nil
            }

            let keyCode = UInt32(event.keyCode)
            let keyName = HotkeyRecorder.keyName(for: event)
            let display = (displayMods + [keyName]).joined(separator: " ")
            onCaptured(keyCode, mods, display)
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
