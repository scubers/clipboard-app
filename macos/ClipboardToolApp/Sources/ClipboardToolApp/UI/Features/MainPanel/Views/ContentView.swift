import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: MainPanelViewModel
    @ObservedObject var appState = AppStore.shared

    @FocusState private var focus: FocusTarget?

    enum FocusTarget {
        case search
        case list
    }

    private var layoutIcon: String {
        switch appState.previewLayout {
        case .previewRight:
            return "rectangle.righthalf.filled"
        case .previewLeft:
            return "rectangle.lefthalf.filled"
        case .previewBottom:
            return "rectangle.bottomhalf.filled"
        }
    }

    var body: some View {
        ZStack {
            VisualEffectMaterial(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()

            // Simple readability tint on top of the material.
            Rectangle()
                .fill(Color.black.opacity(appState.backgroundTint))
                .ignoresSafeArea()

            VStack(spacing: 10) {
                MainPanelSearchBar(
                    vm: vm,
                    focus: $focus,
                    layoutIcon: layoutIcon,
                    onCycleLayout: { appState.previewLayout = appState.previewLayout.next }
                )
                .help("Layout: \(appState.previewLayout.title) (cycle R → L → B)")

                if let err = vm.error {
                    Text(err)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                MainPanelBody(
                    vm: vm,
                    store: appState,
                    focus: $focus,
                    visibleIDs: $visibleIDs,
                    lastSelectedID: $lastSelectedID,
                    lastClickID: $lastClickID,
                    lastClickAt: $lastClickAt,
                    onDelete: { showDeleteConfirmationForSelectedItem() }
                )

                MainPanelFooter(count: vm.filteredItems.count)
            }
            .padding(12)
        }
        .onAppear {
            vm.bootstrap()
            focus = .search
        }
        .onChange(of: vm.selectedID) { _, _ in
            vm.loadPreview()
        }
        .onChange(of: vm.focusTarget) { _, newTarget in
            if let newTarget {
                switch newTarget {
                case .search:
                    focus = .search
                case .list:
                    focus = .list
                }
            }
        }
        // Handle delete request from keyboard shortcut (Cmd+D)
        .onChange(of: vm.deleteRequest) { _, newRequest in
            if let item = newRequest {
                itemToDelete = item
                showDeleteConfirmation = true
                // Clear the request after handling
                vm.deleteRequest = nil
            }
        }
        .alert(deleteConfirmationTitle, isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button(itemToDelete?.pinned == true ? "Delete Anyway" : "Delete", role: .destructive) {
                performDelete()
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    private func performDelete() {
        guard let item = itemToDelete else { return }
        vm.deleteItem(id: item.id, isPinned: item.pinned, confirmCallback: nil) { _ in
            itemToDelete = nil
        }
    }

    @State private var visibleIDs: Set<String> = []
    @State private var lastSelectedID: String?

    // For manual double-click detection (to keep single-click instantaneous).
    @State private var lastClickID: String?
    @State private var lastClickAt: Date?

    // Delete confirmation state
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: Item?
}

// MARK: - Delete Confirmation Extension

extension ContentView {
    /// Show delete confirmation for the currently selected item
    func showDeleteConfirmationForSelectedItem() {
        guard let selectedID = vm.selectedID,
              let item = vm.filteredItems.first(where: { $0.id == selectedID }) else {
            return
        }
        itemToDelete = item
        showDeleteConfirmation = true
    }

    /// Show delete confirmation for an item
    func confirmDelete(item: Item) {
        itemToDelete = item
        showDeleteConfirmation = true
    }

    /// Get confirmation dialog title based on item pinned state
    var deleteConfirmationTitle: String {
        itemToDelete?.pinned == true ? "Delete pinned item?" : "Delete item?"
    }

    /// Get confirmation dialog message based on item pinned state
    var deleteConfirmationMessage: String {
        if itemToDelete?.pinned == true {
            return "This item is pinned. Deleting it will permanently remove it from your clipboard history."
        }
        return "This will permanently delete this item from your clipboard history."
    }
}
