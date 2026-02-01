import AppKit
import Combine
import Foundation

@MainActor
final class MainPanelViewModel: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published var filter: ItemFilter = .all {
        didSet {
            UserDefaults.standard.set(filter.rawValue, forKey: Keys.filter)
            applyFilterAndSelection()
        }
    }

    // Items after applying type filter (all/text/images)
    @Published private(set) var filteredItems: [Item] = []
    @Published var query: String = ""

    private var queryCancellable: AnyCancellable?
    @Published var selectedID: String?
    @Published var previewText: String = ""
    @Published var previewImage: NSImage?
    @Published var error: String?

    private let store = AppStore.shared
    private var core: CoreClient { store.core }
    private var monitor: PasteboardMonitor { store.monitor }

    private enum Keys {
        static let selectedID = "ClipboardTool.selectedID"
        static let filter = "ClipboardTool.filter"
    }

    init() {
        // UI-only preferences are managed by AppStore; this VM handles list/search behavior.

        let savedFilter = UserDefaults.standard.integer(forKey: Keys.filter)
        if let f = ItemFilter(rawValue: savedFilter) {
            filter = f
        }

        if let sid = UserDefaults.standard.string(forKey: Keys.selectedID), !sid.isEmpty {
            selectedID = sid
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
            // Core is opened by AppStore on app start; but if something failed,
            // try again using the current shared data dir.
            try core.open(dataDir: store.sharedDataDir)
            refresh()
        } catch {
            self.error = String(describing: error)
        }
    }

    func refresh() {
        Task { @MainActor in
            do {
                error = nil
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if q.isEmpty {
                    items = try core.list()
                    applyFilterAndSelection()
                    return
                }

                // 1) Initial search (may include OCR hits already).
                items = try core.search(q)
                applyFilterAndSelection()

                // 2) On-demand OCR (queue): keep draining backlog serially with low intensity.
                store.ocrQueue.kick(core: core)
            } catch {
                self.error = String(describing: error)
            }
        }
    }

    func selectPrev() {
        guard !filteredItems.isEmpty else { return }
        guard let sel = selectedID, let idx = filteredItems.firstIndex(where: { $0.id == sel }) else {
            selectedID = filteredItems.first?.id
            return
        }
        let ni = max(0, idx - 1)
        selectedID = filteredItems[ni].id
    }

    func selectNext() {
        guard !filteredItems.isEmpty else { return }
        guard let sel = selectedID, let idx = filteredItems.firstIndex(where: { $0.id == sel }) else {
            selectedID = filteredItems.first?.id
            return
        }
        let ni = min(filteredItems.count - 1, idx + 1)
        selectedID = filteredItems[ni].id
    }

    private func applyFilterAndSelection() {
        switch filter {
        case .all:
            filteredItems = items
        case .text:
            filteredItems = items.filter { $0.type == "text" }
        case .images:
            filteredItems = items.filter { $0.type == "image" }
        }

        // Keep selection stable if possible.
        if filteredItems.isEmpty {
            selectedID = nil
            UserDefaults.standard.removeObject(forKey: Keys.selectedID)
            return
        }

        if let sel = selectedID, filteredItems.contains(where: { $0.id == sel }) {
            // ok
        } else {
            selectedID = filteredItems.first?.id
        }

        if let sel = selectedID {
            UserDefaults.standard.set(sel, forKey: Keys.selectedID)
        }
    }

    // pollIntervalMs is managed by AppStore.

    func loadPreview() {
        guard let id = selectedID else {
            previewText = ""
            previewImage = nil
            return
        }
        UserDefaults.standard.set(id, forKey: Keys.selectedID)
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

            // Treat copy as "entering system clipboard" for ordering.
            try core.touchLastCopied(id: id)

            let pb = NSPasteboard.general
            pb.clearContents()

            if let item = items.first(where: { $0.id == id }), item.type == "image" {
                let p = try core.getBlobPath(id: id)
                try writeImageToPasteboard(filePath: p)
                return
            }

            let text = try core.getText(id: id)
            pb.setString(text, forType: .string)

            // Refresh ordering immediately.
            NotificationCenter.default.post(name: .clipboardToolItemsChanged, object: nil)
        } catch {
            self.error = String(describing: error)
        }
    }

    func pasteSelectedToPreviousApp() {
        guard let id = selectedID else { return }
        do {
            // Avoid feedback loop: our own copy action changes pasteboard.
            monitor.suppress(for: max(0.6, monitor.interval * 2))

            // Treat paste as "entering system clipboard" for ordering.
            try core.touchLastCopied(id: id)

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
                NotificationCenter.default.post(name: .clipboardToolItemsChanged, object: nil)
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
            NotificationCenter.default.post(name: .clipboardToolItemsChanged, object: nil)
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

    // (no-op)
}
