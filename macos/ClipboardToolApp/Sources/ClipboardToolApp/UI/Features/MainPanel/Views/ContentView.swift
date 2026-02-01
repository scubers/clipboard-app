import SwiftUI

struct ContentView: View {
    @StateObject private var vm = MainPanelViewModel()
    @StateObject private var appState = AppStore.shared

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
                    lastClickAt: $lastClickAt
                )

                MainPanelFooter(count: vm.filteredItems.count)
            }
            .padding(12)
        }
        .onAppear {
            vm.bootstrap()
            focus = .search
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardToolFocusSearch)) { _ in
            focus = .search
            // Per spec: each activation jumps to top and selects first item.
            vm.selectedID = vm.filteredItems.first?.id
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardToolSelectPrev)) { _ in
            vm.selectPrev()
            focus = .list
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardToolSelectNext)) { _ in
            vm.selectNext()
            focus = .list
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardToolPasteAction)) { _ in
            // Default Enter behavior: paste.
            vm.pasteSelectedToPreviousApp()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardToolItemsChanged)) { _ in
            if vm.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                vm.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardToolStorageChanged)) { _ in
            vm.refresh()
        }
        .onChange(of: vm.selectedID) { _, _ in
            vm.loadPreview()
        }
    }

    @State private var visibleIDs: Set<String> = []
    @State private var lastSelectedID: String?

    // For manual double-click detection (to keep single-click instantaneous).
    @State private var lastClickID: String?
    @State private var lastClickAt: Date?
}
