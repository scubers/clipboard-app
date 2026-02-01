import AppKit
import SwiftUI

/// Best-effort window chrome tuning for SwiftUI scenes (e.g., Settings).
/// Keeps traffic lights visible but makes the titlebar background match our glass material.
///
/// Note: Some window chrome properties can be reset/reapplied when moving between displays.
/// We listen for relevant window notifications and re-apply.
struct WindowChromeTuner: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.hostView = v
        DispatchQueue.main.async {
            context.coordinator.attachIfPossible()
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        DispatchQueue.main.async {
            context.coordinator.attachIfPossible()
            context.coordinator.applyIfPossible()
        }
    }

    final class Coordinator {
        weak var hostView: NSView?
        weak var window: NSWindow?

        private var observers: [Any] = []

        deinit {
            detach()
        }

        func attachIfPossible() {
            guard let v = hostView, let w = v.window else { return }
            if window === w { return }

            detach()
            window = w

            // Apply once immediately.
            applyIfPossible()

            // Re-apply when window moves / changes screen.
            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: w,
                queue: .main
            ) { [weak self] _ in
                self?.applyIfPossible()
            })

            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeScreenNotification,
                object: w,
                queue: .main
            ) { [weak self] _ in
                self?.applyIfPossible()
            })

            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: w,
                queue: .main
            ) { [weak self] _ in
                self?.applyIfPossible()
            })
        }

        func detach() {
            for o in observers {
                NotificationCenter.default.removeObserver(o)
            }
            observers.removeAll()
            window = nil
        }

        func applyIfPossible() {
            guard let window else { return }

            // Extend the content view into the titlebar so our SwiftUI glass background
            // can be visible behind the traffic lights.
            window.styleMask.insert(.fullSizeContentView)

            // Make titlebar blend with our glass background.
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }

            window.isOpaque = false
            window.backgroundColor = .clear

            // Allow dragging via background.
            window.isMovableByWindowBackground = true

            // Keep traffic lights (do NOT hide standard window buttons).
        }
    }
}
