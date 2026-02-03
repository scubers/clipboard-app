import SwiftUI

struct MainPanelPreviewPane: View {
    @ObservedObject var vm: MainPanelViewModel
    @ObservedObject var store: AppStore
    let onDelete: () -> Void

    var body: some View {
        PreviewCardView(vm: vm, wrap: store.previewWrap, monospace: store.previewMonospace, onDelete: onDelete)
    }
}
