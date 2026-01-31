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
    @Published var pollIntervalMs: Double = SharedAppState.shared.pollIntervalMs {
        didSet {
            SharedAppState.shared.pollIntervalMs = pollIntervalMs
            SharedAppState.shared.applyPollInterval()
        }
    }
    @Published var monitoringEnabled: Bool = SharedAppState.shared.monitoringEnabled {
        didSet {
            SharedAppState.shared.monitoringEnabled = monitoringEnabled
        }
    }

    private let core = SharedAppState.shared.core
    private var monitor: PasteboardMonitor { SharedAppState.shared.monitor }

    private enum Keys {
        static let previewWrap = "ClipboardTool.previewWrap"
        static let previewMonospace = "ClipboardTool.previewMonospace"
    }

    init() {
        if UserDefaults.standard.object(forKey: Keys.previewWrap) != nil {
            previewWrap = UserDefaults.standard.bool(forKey: Keys.previewWrap)
        }
        if UserDefaults.standard.object(forKey: Keys.previewMonospace) != nil {
            previewMonospace = UserDefaults.standard.bool(forKey: Keys.previewMonospace)
        }
    }

    func bootstrap() {
        do {
            try core.open(dataDir: Self.defaultDataDir)
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
        SharedAppState.shared.pollIntervalMs = pollIntervalMs
        SharedAppState.shared.applyPollInterval()
        pollIntervalMs = SharedAppState.shared.pollIntervalMs
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
