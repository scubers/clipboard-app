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
    }

    @State private var visibleIDs: Set<String> = []
    @State private var lastSelectedID: String?

    // For manual double-click detection (to keep single-click instantaneous).
    @State private var lastClickID: String?
    @State private var lastClickAt: Date?
}
