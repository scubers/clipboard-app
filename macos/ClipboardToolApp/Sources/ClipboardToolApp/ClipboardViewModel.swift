import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var query: String = ""

    private var queryCancellable: AnyCancellable?
    @Published var selectedID: String?
    @Published var previewText: String = ""
    @Published var previewImage: NSImage?
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

        // Debounced search refresh while typing.
        queryCancellable = $query
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .debounce(for: .milliseconds(180), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
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
            previewImage = nil
            return
        }
        do {
            error = nil

            if let item = items.first(where: { $0.id == id }), item.type == "image" {
                let p = try core.getBlobPath(id: id)
                previewImage = NSImage(contentsOfFile: p)
                previewText = previewImage == nil ? "(Failed to load image preview)" : ""
                return
            }

            previewImage = nil
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

            let pb = NSPasteboard.general
            pb.clearContents()

            if let item = items.first(where: { $0.id == id }), item.type == "image" {
                let p = try core.getBlobPath(id: id)
                try writeImageToPasteboard(filePath: p)
                return
            }

            let text = try core.getText(id: id)
            pb.setString(text, forType: .string)
        } catch {
            self.error = String(describing: error)
        }
    }

    func pasteSelectedToPreviousApp() {
        guard let id = selectedID else { return }
        do {
            // Avoid feedback loop: our own copy action changes pasteboard.
            monitor.suppress(for: max(0.6, monitor.interval * 2))

            // Copy selected item to system clipboard.
            let pb = NSPasteboard.general
            pb.clearContents()

            if let item = items.first(where: { $0.id == id }), item.type == "image" {
                let p = try core.getBlobPath(id: id)
                try writeImageToPasteboard(filePath: p)
                NotificationCenter.default.post(
                    name: .clipboardToolPasteSelection,
                    object: nil,
                    userInfo: [ClipboardToolNotificationKeys.kind: "image"]
                )
                return
            }

            let text = try core.getText(id: id)
            pb.setString(text, forType: .string)

            NotificationCenter.default.post(
                name: .clipboardToolPasteSelection,
                object: nil,
                userInfo: [
                    ClipboardToolNotificationKeys.kind: "text",
                    ClipboardToolNotificationKeys.text: text,
                ]
            )
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

    private func writeImageToPasteboard(filePath: String) throws {
        let url = URL(fileURLWithPath: filePath)
        let ext = url.pathExtension.lowercased()

        let pb = NSPasteboard.general
        pb.clearContents()

        let item = NSPasteboardItem()

        // 1) Put original bytes for apps that prefer the source type
        let original = try Data(contentsOf: url)
        switch ext {
        case "png":
            item.setData(original, forType: .png)
        case "jpg", "jpeg":
            item.setData(original, forType: NSPasteboard.PasteboardType("public.jpeg"))
        case "tif", "tiff":
            item.setData(original, forType: .tiff)
        case "webp":
            item.setData(original, forType: NSPasteboard.PasteboardType("public.webp"))
        default:
            break
        }

        // 2) Also provide a TIFF representation for broad compatibility
        if let img = NSImage(contentsOf: url),
           let tiff = img.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }

        pb.writeObjects([item])
    }

    static var defaultDataDir: String {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClipboardTool", isDirectory: true)
        return base.path
    }
}
