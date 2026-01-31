import AppKit
import Foundation

@MainActor
final class PasteboardMonitor {
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private var suppressedUntil: Date?

    var interval: TimeInterval {
        didSet {
            // If running, restart timer with new interval.
            if timer != nil {
                stop()
                start()
            }
        }
    }

    var onText: ((String) -> Void)?

    init(pasteboard: NSPasteboard = .general, interval: TimeInterval = 0.5) {
        self.pasteboard = pasteboard
        self.interval = interval
        self.lastChangeCount = pasteboard.changeCount
    }

    func suppress(for seconds: TimeInterval) {
        suppressedUntil = Date().addingTimeInterval(seconds)
    }

    func start() {
        guard timer == nil else { return }
        lastChangeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let cc = pasteboard.changeCount
        guard cc != lastChangeCount else { return }
        lastChangeCount = cc

        if let until = suppressedUntil, Date() < until {
            return
        }

        if let s = pasteboard.string(forType: .string), !s.isEmpty {
            onText?(s)
        }
    }
}
