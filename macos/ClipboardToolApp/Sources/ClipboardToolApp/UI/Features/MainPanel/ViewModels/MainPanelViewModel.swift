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

    // Focus state: nil = no change, .search = focus search, .list = focus list
    @Published var focusTarget: FocusTarget? = nil

    enum FocusTarget {
        case search
        case list
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
    private var repo: ClipboardRepository { store.clipboardRepo }
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

        // Subscribe to AppStore data changes instead of NotificationCenter.
        // When itemsVersion changes, refresh the list (only if query is empty to avoid duplicate queries).
        subscribeToStoreChanges()
    }

    private func subscribeToStoreChanges() {
        store.$itemsVersion
            .sink { [weak self] _ in
                guard let self else { return }
                // Only refresh automatically when not in search mode.
                // This prevents duplicate queries when user is typing.
                if self.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    func bootstrap() {
        do {
            // Core is opened by AppStore on app start; but if something failed,
            // try again using the current shared data dir.
            try repo.open(dataDir: store.sharedDataDir)
            refresh()
        } catch {
            self.error = String(describing: error)
        }
    }

    func resetFocusToSearch() {
        // Reset selection to first item and focus to search.
        selectedID = filteredItems.first?.id
        focusTarget = .search
    }

    private func updateFocusToNext() {
        focusTarget = .list
    }

    func refresh() {
        Task { @MainActor in
            do {
                error = nil
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if q.isEmpty {
                    items = try repo.list(limit: 200, offset: 0)
                    applyFilterAndSelection()
                    return
                }

                // 1) Initial search (may include OCR hits already).
                items = try repo.search(q, limit: 200, offset: 0)
                applyFilterAndSelection()

                // 2) On-demand OCR (queue): keep draining backlog serially with low intensity.
                store.ocrQueue.kick(core: store.core)
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
                let p = try repo.getBlobPath(id: id)
                previewImage = NSImage(contentsOfFile: p)
                previewText = previewImage == nil ? "(Failed to load image preview)" : ""
                return
            }

            previewImage = nil
            previewText = try repo.getText(id: id)
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
            try repo.touchLastCopied(id: id)

            let pb = NSPasteboard.general
            pb.clearContents()

            if let item = items.first(where: { $0.id == id }), item.type == "image" {
                let p = try repo.getBlobPath(id: id)
                try writeImageToPasteboard(filePath: p)
                // Refresh ordering immediately.
                store.incrementItemsVersion()
                return
            }

            let text = try repo.getText(id: id)
            pb.setString(text, forType: .string)

            // Refresh ordering immediately.
            store.incrementItemsVersion()
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
            try repo.touchLastCopied(id: id)

            // Copy selected item to system clipboard.
            let pb = NSPasteboard.general
            pb.clearContents()

            if let item = items.first(where: { $0.id == id }), item.type == "image" {
                let p = try repo.getBlobPath(id: id)
                try writeImageToPasteboard(filePath: p)
                // Refresh ordering immediately.
                store.incrementItemsVersion()
                // Notify callback to switch to previous app and send Cmd+V
                store.onPasteComplete?("image", nil)
                return
            }

            let text = try repo.getText(id: id)
            pb.setString(text, forType: .string)

            // Refresh ordering immediately.
            store.incrementItemsVersion()
            // Notify callback to switch to previous app and send Cmd+V
            store.onPasteComplete?("text", text)
        } catch {
            self.error = String(describing: error)
        }
    }

    func addTestItem() {
        do {
            try repo.addText("test item @ \(Date())", sourceApp: nil)
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
