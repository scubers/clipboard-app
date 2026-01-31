import AppKit
import Foundation

@MainActor
final class ClipboardViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var query: String = ""
    @Published var selectedID: String?
    @Published var previewText: String = ""
    @Published var error: String?

    // Preview settings (persisted via UserDefaults)
    @Published var previewWrap: Bool = true {
        didSet { UserDefaults.standard.set(previewWrap, forKey: Keys.previewWrap) }
    }
    @Published var previewMonospace: Bool = true {
        didSet { UserDefaults.standard.set(previewMonospace, forKey: Keys.previewMonospace) }
    }

    // Settings (persisted via UserDefaults)
    @Published var pollIntervalMs: Double = 500 {
        didSet { UserDefaults.standard.set(pollIntervalMs, forKey: Keys.pollIntervalMs) }
    }
    @Published var monitoringEnabled: Bool = true {
        didSet { UserDefaults.standard.set(monitoringEnabled, forKey: Keys.monitoringEnabled) }
    }

    private let core = SharedAppState.shared.core
    private let monitor = PasteboardMonitor(interval: 0.5)

    private enum Keys {
        static let pollIntervalMs = "ClipboardTool.pollIntervalMs"
        static let monitoringEnabled = "ClipboardTool.monitoringEnabled"
        static let previewWrap = "ClipboardTool.previewWrap"
        static let previewMonospace = "ClipboardTool.previewMonospace"
    }

    init() {
        let savedMs = UserDefaults.standard.double(forKey: Keys.pollIntervalMs)
        if savedMs > 0 {
            pollIntervalMs = savedMs
        }
        if UserDefaults.standard.object(forKey: Keys.monitoringEnabled) != nil {
            monitoringEnabled = UserDefaults.standard.bool(forKey: Keys.monitoringEnabled)
        }
        if UserDefaults.standard.object(forKey: Keys.previewWrap) != nil {
            previewWrap = UserDefaults.standard.bool(forKey: Keys.previewWrap)
        }
        if UserDefaults.standard.object(forKey: Keys.previewMonospace) != nil {
            previewMonospace = UserDefaults.standard.bool(forKey: Keys.previewMonospace)
        }
        applyPollInterval()
    }

    func bootstrap() {
        do {
            try core.open(dataDir: Self.defaultDataDir)

            monitor.onText = { [weak self] text, sourceApp in
                guard let self else { return }
                guard self.monitoringEnabled else { return }
                do {
                    try self.core.addText(text, sourceApp: sourceApp)
                    // If the user isn't actively searching, keep list live.
                    if self.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.refresh()
                    }
                } catch {
                    self.error = String(describing: error)
                }
            }

            monitor.start()
            refresh()
        } catch {
            self.error = String(describing: error)
        }
    }

    func refresh() {
        do {
            error = nil
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                items = try core.list()
            } else {
                items = try core.search(query)
            }
        } catch {
            self.error = String(describing: error)
        }
    }

    func applyPollInterval() {
        let ms = max(100, min(2000, pollIntervalMs))
        pollIntervalMs = ms
        monitor.interval = ms / 1000.0
    }

    func loadPreview() {
        guard let id = selectedID else {
            previewText = ""
            return
        }
        do {
            error = nil
            previewText = try core.getText(id: id)
        } catch {
            self.error = String(describing: error)
        }
    }

    func copySelectedToPasteboard() {
        guard let id = selectedID else { return }
        do {
            // Avoid feedback loop: our own copy action changes pasteboard.
            monitor.suppress(for: max(0.6, monitor.interval * 2))

            let text = try core.getText(id: id)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        } catch {
            self.error = String(describing: error)
        }
    }

    func addTestItem() {
        do {
            try core.addText("test item @ \(Date())")
            refresh()
        } catch {
            self.error = String(describing: error)
        }
    }

    static var defaultDataDir: String {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClipboardTool", isDirectory: true)
        return base.path
    }
}
