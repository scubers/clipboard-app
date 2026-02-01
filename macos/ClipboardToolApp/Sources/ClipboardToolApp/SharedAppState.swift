import Foundation

// A very small shared container so SettingsView can talk to the same CoreClient
// as the main content window.
@MainActor
final class SharedAppState: ObservableObject {
    static let shared = SharedAppState()

    let core = CoreClient()
    let monitor = PasteboardMonitor(interval: 0.5)

    @Published private(set) var sharedDataDir: String = AppPaths.effectiveSharedDir().path

    // UI layout (persisted via UserDefaults)
    @Published var previewLayout: PreviewLayout = .previewRight {
        didSet { UserDefaults.standard.set(previewLayout.rawValue, forKey: Keys.previewLayout) }
    }

    // Settings (persisted via UserDefaults)
    @Published var pollIntervalMs: Double = 500 {
        didSet { UserDefaults.standard.set(pollIntervalMs, forKey: Keys.pollIntervalMs) }
    }
    @Published var monitoringEnabled: Bool = true {
        didSet { UserDefaults.standard.set(monitoringEnabled, forKey: Keys.monitoringEnabled) }
    }

    private enum Keys {
        static let pollIntervalMs = "ClipboardTool.pollIntervalMs"
        static let monitoringEnabled = "ClipboardTool.monitoringEnabled"
        static let previewLayout = "ClipboardTool.previewLayout"
    }

    private init() {
        // Best-effort open with shared dir (configurable via local config).
        let dir = AppPaths.effectiveSharedDir().path
        sharedDataDir = dir
        try? core.open(dataDir: dir)

        let savedMs = UserDefaults.standard.double(forKey: Keys.pollIntervalMs)
        if savedMs > 0 {
            pollIntervalMs = savedMs
        }
        if UserDefaults.standard.object(forKey: Keys.monitoringEnabled) != nil {
            monitoringEnabled = UserDefaults.standard.bool(forKey: Keys.monitoringEnabled)
        }

        let savedLayout = UserDefaults.standard.integer(forKey: Keys.previewLayout)
        if let l = PreviewLayout(rawValue: savedLayout) {
            previewLayout = l
        }

        applyPollInterval()
    }

    func applyPollInterval() {
        let ms = max(100, min(2000, pollIntervalMs))
        pollIntervalMs = ms
        monitor.interval = ms / 1000.0
    }

    func reloadSharedDataDir(_ newDir: String) throws {
        let trimmed = newDir.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Persist to local config.
        let url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
        try AppPaths.setSharedDir(url)

        // Reopen core against the new directory.
        try core.reopen(dataDir: url.path)
        sharedDataDir = url.path

        // Tell UI to refresh.
        NotificationCenter.default.post(name: .clipboardToolStorageChanged, object: nil)
        NotificationCenter.default.post(name: .clipboardToolItemsChanged, object: nil)
    }

    func startMonitoring() {
        monitor.onText = { [weak self] text, sourceApp in
            guard let self else { return }
            guard self.monitoringEnabled else { return }
            do {
                try self.core.addText(text, sourceApp: sourceApp)
                NotificationCenter.default.post(name: .clipboardToolItemsChanged, object: nil)
            } catch {
                // Swallow errors: we don't want clipboard monitoring to crash the app.
            }
        }

        monitor.onImage = { [weak self] data, mime, sourceApp in
            guard let self else { return }
            guard self.monitoringEnabled else { return }
            do {
                try self.core.addImage(mime: mime, data: data, sourceApp: sourceApp)
                NotificationCenter.default.post(name: .clipboardToolItemsChanged, object: nil)
            } catch {
                // Swallow errors: we don't want clipboard monitoring to crash the app.
            }
        }
        monitor.start()
    }
}
