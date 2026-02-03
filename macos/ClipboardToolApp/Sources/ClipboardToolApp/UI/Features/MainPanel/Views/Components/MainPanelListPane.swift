import SwiftUI

struct MainPanelListPane: View {
    @ObservedObject var vm: MainPanelViewModel
    let focus: FocusState<ContentView.FocusTarget?>.Binding

    @Binding var visibleIDs: Set<String>
    @Binding var lastSelectedID: String?

    // For manual double-click detection (to keep single-click instantaneous).
    @Binding var lastClickID: String?
    @Binding var lastClickAt: Date?

    // Delete confirmation state
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: Item?
    
    // Tag editor state
    @State private var showTagEditor = false
    @State private var itemForTagEditor: Item?

    var body: some View {
        let items = vm.filteredItems

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        makeItemRow(item: item, proxy: proxy)
                    }
                }
                .padding(2)
            }
            .scrollIndicators(.automatic)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .onChange(of: vm.selectedID) { oldValue, newValue in
                scrollIfNeeded(proxy: proxy, oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: vm.focusTarget) { _, newTarget in
                if newTarget == .search, let first = items.first?.id {
                    DispatchQueue.main.async { proxy.scrollTo(first, anchor: .top) }
                }
            }
        }
        .focused(focus, equals: .list)
        // Sync alert presentation state to ViewModel so PanelCoordinator knows to disable shortcuts
        .onChange(of: showDeleteConfirmation) { _, isPresented in
            vm.modalState = isPresented ? .deleteAlert : .none
        }
        // Note: Button order matters for default keyboard behavior.
        // First button gets default Enter key action.
        // Delete button first so Enter confirms delete, Esc triggers Cancel (.cancel role).
        .alert(deleteConfirmationTitle, isPresented: $showDeleteConfirmation) {
            Button(itemToDelete?.pinned == true ? "Delete Anyway" : "Delete") {
                performDelete()
            }
            Button("Cancel") {
                itemToDelete = nil
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
        // Tag Editor sheet
        .sheet(item: $itemForTagEditor) { item in
            TagEditorView(itemID: item.id, vm: vm) { changedItemID in
                // Refresh tags for the modified item
                vm.refreshTags(for: changedItemID)
            }
        }
    }

    private var deleteConfirmationTitle: String {
        itemToDelete?.pinned == true ? "Delete pinned item?" : "Delete item?"
    }

    private var deleteConfirmationMessage: String {
        if itemToDelete?.pinned == true {
            return "This item is pinned. Deleting it will permanently remove it from your clipboard history."
        }
        return "This will permanently delete this item from your clipboard history."
    }

    private func performDelete() {
        guard let item = itemToDelete else { return }
        vm.deleteItem(id: item.id, isPinned: item.pinned, confirmCallback: nil) { _ in
            itemToDelete = nil
        }
    }

    private func makeItemRow(item: Item, proxy: ScrollViewProxy) -> some View {
        ItemRowView(
            item: item,
            tags: vm.getTags(for: item.id),
            selected: vm.selectedID == item.id,
            isDeleting: vm.isDeleting(id: item.id),
            onDelete: { handleDelete(item: item) },
            onCopy: { handleCopy(item: item) },
            onPaste: { handlePaste(item: item) },
            onAddTags: { handleAddTags(item: item) }
        )
        .id(item.id)
        .contentShape(Rectangle())
        .onTapGesture { handleRowTap(itemID: item.id) }
        .onAppear { visibleIDs.insert(item.id) }
        .onDisappear { visibleIDs.remove(item.id) }
    }

    private func handleRowTap(itemID: String) {
        let now = Date()
        vm.selectedID = itemID

        if let lastID = lastClickID,
           let lastAt = lastClickAt,
           lastID == itemID,
           now.timeIntervalSince(lastAt) < 0.32 {
            lastClickID = nil
            lastClickAt = nil
            vm.pasteSelectedToPreviousApp()
        } else {
            lastClickID = itemID
            lastClickAt = now
        }
    }

    private func handleDelete(item: Item) {
        vm.selectedID = item.id
        itemToDelete = item
        showDeleteConfirmation = true
    }

    private func handleCopy(item: Item) {
        vm.selectedID = item.id
        vm.copySelectedToPasteboard()
    }

    private func handlePaste(item: Item) {
        vm.selectedID = item.id
        vm.pasteSelectedToPreviousApp()
    }

    private func handleAddTags(item: Item) {
        vm.selectedID = item.id
        itemForTagEditor = item
        showTagEditor = true
    }

    private func scrollIfNeeded(proxy: ScrollViewProxy, oldValue: String?, newValue: String?) {
        guard let id = newValue else { return }
        guard !visibleIDs.contains(id) else {
            lastSelectedID = id
            return
        }

        let newIdx = vm.filteredItems.firstIndex(where: { $0.id == id })
        let oldIdx = (oldValue != nil) ? vm.filteredItems.firstIndex(where: { $0.id == oldValue! }) : nil

        let movingDown: Bool
        if let n = newIdx, let o = oldIdx {
            movingDown = n > o
        } else if let last = lastSelectedID,
                  let n = newIdx,
                  let o = vm.filteredItems.firstIndex(where: { $0.id == last }) {
            movingDown = n > o
        } else {
            movingDown = true
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.10)) {
                proxy.scrollTo(id, anchor: movingDown ? .bottom : .top)
            }
        }
        lastSelectedID = id
    }
}
