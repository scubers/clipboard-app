import AppKit
import Foundation

/// Monitors system clipboard for changes and dispatches events to handlers
///
/// Design Principles:
/// 1. Detection Only: This class only detects clipboard changes
/// 2. Handler Delegation: Actual content processing is delegated to registered handlers
/// 3. Suppression: Can be temporarily suppressed to avoid feedback loops
@MainActor
final class PasteboardMonitor {
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private var suppressedUntil: Date?

    /// Polling interval in seconds
    var interval: TimeInterval {
        didSet {
            // If running, restart timer with new interval.
            if timer != nil {
                stop()
                start()
            }
        }
    }

    /// Registry of clipboard content handlers
    ///
    /// Handlers should be registered before calling `start()`.
    let handlerRegistry = ClipboardHandlerRegistry()

    /// Optional callback for monitoring activity
    var onActivity: ((Bool) -> Void)?

    init(pasteboard: NSPasteboard = .general, interval: TimeInterval = 0.5) {
        self.pasteboard = pasteboard
        self.interval = interval
        self.lastChangeCount = pasteboard.changeCount

        // Set up default logging for unknown types
        let logger = UnknownTypeLoggerHandler()
        handlerRegistry.onUnhandledEvent = { event in
            logger.logUnhandled(event)
        }
    }

    /// Suppress clipboard change detection for a duration
    ///
    /// Useful after copying to clipboard to avoid feedback loops.
    ///
    /// - Parameter seconds: Duration to suppress in seconds
    func suppress(for seconds: TimeInterval) {
        suppressedUntil = Date().addingTimeInterval(seconds)
    }

    /// Start monitoring clipboard changes
    func start() {
        guard timer == nil else { return }
        lastChangeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }

        onActivity?(true)
    }

    /// Stop monitoring clipboard changes
    func stop() {
        timer?.invalidate()
        timer = nil
        onActivity?(false)
    }

    private func tick() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Check if suppression is active
        if let until = suppressedUntil, Date() < until {
            return
        }

        // Best-effort source app capture
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName

        // Create clipboard event and dispatch to handlers
        let event = ClipboardEvent(
            pasteboard: pasteboard,
            sourceApp: appName,
            timestamp: Date()
        )

        // Process event asynchronously (handler may do async work like OCR)
        Task {
            _ = await handlerRegistry.process(event)
        }
    }
}
