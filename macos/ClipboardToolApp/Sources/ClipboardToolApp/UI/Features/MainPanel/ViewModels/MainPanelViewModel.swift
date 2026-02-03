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
    
    // Tags cache: itemID -> tags
    @Published var itemTags: [String: [ItemTag]] = [:]
    
    // IDs of items being deleted (for fade-out animation)
    @Published var deletingItemIDs: Set<String> = []
    
    // Delete request for keyboard shortcut (Cmd+D) - triggers confirmation dialog in UI
    @Published var deleteRequest: Item?
    
    // MARK: - Modal State Management
    
    /// Current modal state of MainPanel. When a modal (alert, sheet) is presented,
    /// keyboard shortcuts should be disabled to let the modal handle its own events.
    enum ModalState: Equatable {
        case none           // MainPanel is in normal interactive state
        case deleteAlert    // Delete confirmation alert is presented
        // Future: .settings, .importProgress, etc.
    }
    
    @Published var modalState: ModalState = .none
    
    /// Returns true when MainPanel is in normal interactive state (no modals presented).
    /// Keyboard shortcuts (Enter, arrows, Cmd+D) should only work when this is true.
    var isMainPanelActive: Bool {
        modalState == .none
    }

    private let store = AppStore.shared
    var repo: ClipboardRepository { store.clipboardRepo }
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
        // Clear search query when panel is shown.
        query = ""
        // Reset selection to first item and focus to search.
        selectedID = filteredItems.first?.id
        // Force focus update by clearing first, then setting to search.
        // This ensures onChange triggers every time the panel is shown.
        focusTarget = nil
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
                    loadTagsForVisibleItems()
                    return
                }

                // 1) Initial search (may include OCR hits already).
                items = try repo.search(q, limit: 200, offset: 0)
                applyFilterAndSelection()
                loadTagsForVisibleItems()

                // 2) On-demand OCR (queue): keep draining backlog serially with low intensity.
                store.ocrQueue.kick(core: store.core)
            } catch {
                self.error = String(describing: error)
            }
        }
    }

    private func loadTagsForVisibleItems() {
        Task { @MainActor in
            for item in items {
                do {
                    let tags = try repo.getTags(itemID: item.id)
                    itemTags[item.id] = tags
                } catch {
                    // Silently fail for tags
                }
            }
        }
    }

    func getTags(for itemID: String) -> [ItemTag] {
        return itemTags[itemID] ?? []
    }

    func refreshTags(for itemID: String) {
        Task { @MainActor in
            do {
                let tags = try repo.getTags(itemID: itemID)
                itemTags[itemID] = tags
                print("[MainPanelViewModel] Refreshed tags for item \(itemID): \(tags.count) tags")
            } catch {
                print("[MainPanelViewModel] Failed to refresh tags: \(error)")
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

    // MARK: - Tag Editor
    
    @Published var showTagEditor = false
    @Published var tagEditorItemID: String? = nil
    
    func openTagEditor() {
        guard let selectedID = selectedID else { return }
        tagEditorItemID = selectedID
        showTagEditor = true
    }
    
    // MARK: - Delete Item

    /// Request deletion of the currently selected item (triggered by Cmd+D shortcut)
    /// Sets deleteRequest which ContentView observes to show confirmation dialog
    func requestDeleteSelected() {
        guard let id = selectedID,
              let item = filteredItems.first(where: { $0.id == id }) else {
            return
        }
        deleteRequest = item
    }

    /// Delete an item with optional confirmation callback
    /// - Parameters:
    ///   - id: The item ID to delete
    ///   - isPinned: Whether the item is pinned (affects confirmation message)
    ///   - confirmCallback: Optional callback to show confirmation dialog (returns true if confirmed)
    ///   - completion: Called after deletion completes (success or failure)
    func deleteItem(
        id: String,
        isPinned: Bool,
        confirmCallback: ((String, String, @escaping (Bool) -> Void) -> Void)? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        // If confirmation is needed, call the callback
        if let confirmCallback = confirmCallback {
            let title = isPinned ? "Delete pinned item?" : "Delete item?"
            let message = isPinned
                ? "This item is pinned. Deleting it will permanently remove it from your clipboard history."
                : "This will permanently delete this item from your clipboard history."
            
            confirmCallback(title, message) { [weak self] confirmed in
                if confirmed {
                    self?.performDelete(id: id, completion: completion)
                } else {
                    completion?(false)
                }
            }
        } else {
            performDelete(id: id, completion: completion)
        }
    }

    /// Perform the actual deletion with animation
    private func performDelete(id: String, completion: ((Bool) -> Void)? = nil) {
        // Mark as deleting for animation
        deletingItemIDs.insert(id)
        
        // Animate the fade-out before actual deletion
        Task { @MainActor in
            // Wait for fade-out animation (200ms)
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            do {
                try repo.deleteItem(id: id)
                
                // Handle selection after delete
                if selectedID == id {
                    handleSelectionAfterDelete(deletedID: id)
                }
                
                // Remove from deleting set and refresh
                deletingItemIDs.remove(id)
                refresh()
                
                // Increment items version to trigger UI updates
                store.incrementItemsVersion()
                
                completion?(true)
            } catch {
                // Remove from deleting set on error
                deletingItemIDs.remove(id)
                self.error = String(describing: error)
                completion?(false)
            }
        }
    }

    /// Handle selection after an item is deleted
    private func handleSelectionAfterDelete(deletedID: String) {
        guard !filteredItems.isEmpty else {
            selectedID = nil
            return
        }
        
        // Find the index of the deleted item
        if let idx = filteredItems.firstIndex(where: { $0.id == deletedID }) {
            // Try to select next item, or previous if no next
            let nextIdx = min(idx, filteredItems.count - 1)
            if nextIdx < filteredItems.count {
                selectedID = filteredItems[nextIdx].id
            } else {
                selectedID = filteredItems.first?.id
            }
        } else {
            selectedID = filteredItems.first?.id
        }
    }

    /// Check if an item is being deleted (for animation)
    func isDeleting(id: String) -> Bool {
        deletingItemIDs.contains(id)
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
