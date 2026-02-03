import SwiftUI

struct MainPanelBody: View {
    @ObservedObject var vm: MainPanelViewModel
    @ObservedObject var store: AppStore
    let focus: FocusState<ContentView.FocusTarget?>.Binding

    @Binding var visibleIDs: Set<String>
    @Binding var lastSelectedID: String?
    @Binding var lastClickID: String?
    @Binding var lastClickAt: Date?
    let onDelete: () -> Void

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 12
            let w = geo.size.width
            let h = geo.size.height

            // 60/40 split (list/preview)
            let listW = max(240, (w - spacing) * 0.50)
            let previewW = max(240, (w - spacing) * 0.50)

            let listH = max(160, (h - spacing) * 0.50)
            let previewH = max(160, (h - spacing) * 0.50)

            Group {
                switch store.previewLayout {
                case .previewRight:
                    HStack(spacing: spacing) {
                        MainPanelListPane(
                            vm: vm,
                            focus: focus,
                            visibleIDs: $visibleIDs,
                            lastSelectedID: $lastSelectedID,
                            lastClickID: $lastClickID,
                            lastClickAt: $lastClickAt
                        )
                        .frame(width: listW)

                        MainPanelPreviewPane(vm: vm, store: store, onDelete: onDelete)
                            .frame(width: previewW)
                    }

                case .previewLeft:
                    HStack(spacing: spacing) {
                        MainPanelPreviewPane(vm: vm, store: store, onDelete: onDelete)
                            .frame(width: previewW)

                        MainPanelListPane(
                            vm: vm,
                            focus: focus,
                            visibleIDs: $visibleIDs,
                            lastSelectedID: $lastSelectedID,
                            lastClickID: $lastClickID,
                            lastClickAt: $lastClickAt
                        )
                        .frame(width: listW)
                    }

                case .previewBottom:
                    VStack(spacing: spacing) {
                        MainPanelListPane(
                            vm: vm,
                            focus: focus,
                            visibleIDs: $visibleIDs,
                            lastSelectedID: $lastSelectedID,
                            lastClickID: $lastClickID,
                            lastClickAt: $lastClickAt
                        )
                        .frame(height: listH)

                        MainPanelPreviewPane(vm: vm, store: store, onDelete: onDelete)
                            .frame(height: previewH)
                    }
                }
            }
        }
    }
}
