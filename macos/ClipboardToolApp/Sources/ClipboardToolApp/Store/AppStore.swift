import Foundation

// AppStore is the app-level state container / dependency hub.
@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    let core = CoreClient()
    let clipboardRepo: ClipboardRepository
    let monitor = PasteboardMonitor(interval: 0.5)
    let ocrQueue = OCRQueueManager()

    @Published private(set) var sharedDataDir: String = AppPaths.effectiveSharedDir().path

    // Data change notifications (via @Published instead of NotificationCenter)
    @Published private(set) var itemsVersion: Int = 0
    @Published private(set) var storageVersion: Int = 0

    // Paste completion callback for auto-paste to previous app
    var onPasteComplete: ((String, String?) -> Void)? = nil

    // Increment versions to trigger @Published updates
    func incrementItemsVersion() {
        itemsVersion += 1
    }

    func incrementStorageVersion() {
        storageVersion += 1
        itemsVersion += 1
    }

    // macOS-only syncable settings (stored in <sharedDir>/config/macos.json)
    private var macCfg: MacOSConfigStore.Config
    private var bootstrapping = true

    // UI layout (persisted via macOS config)
    @Published var previewLayout: PreviewLayout {
        didSet { persistMacConfigIfReady() }
    }

    // UI appearance tuning
    @Published var backgroundTint: Double {
        didSet { persistMacConfigIfReady() }
    }

    @Published var hideTrafficLights: Bool {
        didSet { persistMacConfigIfReady() }
    }

    // Preview settings
    @Published var previewWrap: Bool {
        didSet { persistMacConfigIfReady() }
    }

    @Published var previewMonospace: Bool {
        didSet { persistMacConfigIfReady() }
    }

    // Capture settings (macOS)
    @Published var pollIntervalMs: Double {
        didSet {
            let clamped = max(100, min(2000, pollIntervalMs))
            if pollIntervalMs != clamped {
                pollIntervalMs = clamped
                return
            }
            monitor.interval = clamped / 1000.0
            persistMacConfigIfReady()
        }
    }

    @Published var monitoringEnabled: Bool {
        didSet { persistMacConfigIfReady() }
    }

    private init() {
        // Best-effort open with shared dir (configurable via local config).
        let dir = AppPaths.effectiveSharedDir().path
        sharedDataDir = dir
        clipboardRepo = CoreClipboardRepository(core: core)
        try? clipboardRepo.open(dataDir: dir)

        // No legacy UserDefaults migration needed (project not shipped yet).
        let loaded = MacOSConfigStore.load(sharedDir: dir)
        macCfg = loaded ?? MacOSConfigStore.Config()
        if loaded == nil {
            // Create the file so it starts syncing.
            try? MacOSConfigStore.save(macCfg, sharedDir: dir)
        }

        // Initialize published values.
        previewLayout = macCfg.previewLayout
        backgroundTint = macCfg.backgroundTint
        hideTrafficLights = macCfg.hideTrafficLights
        previewWrap = macCfg.previewWrap
        previewMonospace = macCfg.previewMonospace
        pollIntervalMs = macCfg.pollIntervalMs
        monitoringEnabled = macCfg.monitoringEnabled

        bootstrapping = false
        applyPollInterval()
    }

    private func persistMacConfigIfReady() {
        guard !bootstrapping else { return }

        macCfg.previewLayout = previewLayout
        macCfg.backgroundTint = backgroundTint
        macCfg.hideTrafficLights = hideTrafficLights
        macCfg.previewWrap = previewWrap
        macCfg.previewMonospace = previewMonospace
        macCfg.pollIntervalMs = pollIntervalMs
        macCfg.monitoringEnabled = monitoringEnabled

        try? MacOSConfigStore.save(macCfg, sharedDir: sharedDataDir)
    }

    func applyPollInterval() {
        let ms = max(100, min(2000, pollIntervalMs))
        monitor.interval = ms / 1000.0
    }

    func reloadSharedDataDir(_ newDir: String) throws {
        let trimmed = newDir.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Persist to local config.
        let url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
        try AppPaths.setSharedDir(url)

        // Reopen core against the new directory.
        try clipboardRepo.reopen(dataDir: url.path)
        sharedDataDir = url.path

        // Reload macOS settings for the new shared dir.
        bootstrapping = true
        let loaded = MacOSConfigStore.load(sharedDir: url.path)
        macCfg = loaded ?? MacOSConfigStore.Config()
        if loaded == nil {
            try? MacOSConfigStore.save(macCfg, sharedDir: url.path)
        }

        previewLayout = macCfg.previewLayout
        backgroundTint = macCfg.backgroundTint
        hideTrafficLights = macCfg.hideTrafficLights
        previewWrap = macCfg.previewWrap
        previewMonospace = macCfg.previewMonospace
        pollIntervalMs = macCfg.pollIntervalMs
        monitoringEnabled = macCfg.monitoringEnabled

        bootstrapping = false
        applyPollInterval()

        // Tell UI to refresh.
        notifyDataSourceChanged(storageChanged: true)
    }

    func notifyDataSourceChanged(storageChanged: Bool = false) {
        // Data dir or DB contents changed: stop any background OCR work and refresh UI.
        ocrQueue.reset()
        if storageChanged {
            incrementStorageVersion()
        } else {
            incrementItemsVersion()
        }
    }

    func startMonitoring() {
        // Register clipboard content handlers

        // Text handler
        let textHandler = TextHandler(core: core) { [weak self] text, sourceApp in
            guard let self else { return }
            guard self.monitoringEnabled else { return }
            // Ensure @Published updates happen on main thread
            Task { @MainActor in
                self.incrementItemsVersion()
            }
        }
        monitor.handlerRegistry.register(textHandler)

        // Image handler
        let imageHandler = ImageHandler(core: core) { [weak self] data, mime, sourceApp in
            guard let self else { return }
            guard self.monitoringEnabled else { return }
            // Ensure @Published updates happen on main thread
            Task { @MainActor in
                self.incrementItemsVersion()
            }
        }
        monitor.handlerRegistry.register(imageHandler)

        // Start monitoring
        monitor.start()
    }
}
