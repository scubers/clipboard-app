import Foundation

/// A low-intensity, serial OCR queue.
///
/// Goals:
/// - No heavy bursts: process at most 1 image at a time.
/// - Keep draining historical backlog opportunistically.
/// - Avoid duplicate work: dedupe by id.
///
/// Trigger points:
/// - Called from UI refresh/search.
/// - Also keeps scanning for backlog when the app is open.
@MainActor
final class OCRQueueManager: ObservableObject {
    private let maxTextChars = 16_384

    private var pending: [String] = []
    private var pendingSet: Set<String> = []

    private var worker: Task<Void, Never>?
    private var idleSince: Date?

    func reset() {
        worker?.cancel()
        worker = nil
        pending.removeAll(keepingCapacity: true)
        pendingSet.removeAll(keepingCapacity: true)
        idleSince = nil
    }

    func kick(core: CoreClient) {
        // Start worker if not running.
        if worker == nil {
            worker = Task { [weak self] in
                await self?.run(core: core)
            }
        }
    }

    private func enqueue(_ ids: [String]) {
        for id in ids {
            if pendingSet.contains(id) { continue }
            pending.append(id)
            pendingSet.insert(id)
        }
    }

    private func pop() -> String? {
        guard !pending.isEmpty else { return nil }
        let id = pending.removeFirst()
        pendingSet.remove(id)
        return id
    }

    private func run(core: CoreClient) async {
        // Keep running while app is open, but self-throttle.
        while !Task.isCancelled {
            // Refill queue if empty.
            if pending.isEmpty {
                do {
                    let cands = try core.listImagesNeedingOCR(limit: 10)
                    enqueue(cands.filter { $0.type == "image" }.map { $0.id })
                } catch {
                    // If core is temporarily unavailable, backoff.
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }

                if pending.isEmpty {
                    // Nothing to do. Go idle; stop worker after a while.
                    if idleSince == nil { idleSince = Date() }
                    if let idleSince, Date().timeIntervalSince(idleSince) > 30 {
                        worker = nil
                        return
                    }
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    continue
                }
            }

            idleSince = nil

            guard let id = pop() else {
                continue
            }

            // OCR one item.
            do {
                let p = try core.getBlobPath(id: id)
                let r = await OCRService.shared.recognizeText(filePath: p)

                if r.ok {
                    var t = r.text
                    if t.count > maxTextChars {
                        // Fast truncation (core also truncates; this just avoids huge Swift strings).
                        t = String(t.prefix(maxTextChars))
                    }
                    try core.setOCRText(id: id, text: t, status: 1)
                } else {
                    try core.setOCRText(id: id, text: "", status: 2)
                }

                // Slow down to avoid CPU spikes.
                try? await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                // Best-effort: mark failed to avoid infinite retry loops.
                try? core.setOCRText(id: id, text: "", status: 2)
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }
}
