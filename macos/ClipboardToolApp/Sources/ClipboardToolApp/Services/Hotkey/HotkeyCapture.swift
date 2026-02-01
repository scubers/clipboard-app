import AppKit
import SwiftUI

/// Captures a single hotkey chord from local keyDown events.
///
/// Lives in Services because it deals with NSEvent and is reused by Settings UI.
@MainActor
final class HotkeyCapture: ObservableObject {
    @Published var status: String = "Press keys now"

    private var monitor: Any?

    func start(
        onCaptured: @escaping (_ keyCode: UInt32, _ carbonModifiers: UInt32, _ display: String) -> Void,
        onCancel: @escaping () -> Void
    ) {
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
