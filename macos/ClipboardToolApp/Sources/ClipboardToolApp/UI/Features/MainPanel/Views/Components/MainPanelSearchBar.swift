import SwiftUI

struct MainPanelSearchBar: View {
    @ObservedObject var vm: MainPanelViewModel
    var focus: FocusState<ContentView.FocusTarget?>.Binding

    let layoutIcon: String
    let onCycleLayout: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search clipboard…", text: $vm.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                    .focused(focus, equals: .search)
                    .onSubmit { vm.refresh() }
                    .onKeyPress(.downArrow) {
                        focus.wrappedValue = .list
                        if vm.selectedID == nil {
                            vm.selectedID = vm.filteredItems.first?.id
                        }
                        return .handled
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.10), lineWidth: 1))

            HStack(spacing: 8) {
                PillButton(title: "All", selected: vm.filter == .all) { vm.filter = .all }
                PillButton(title: "Text", selected: vm.filter == .text) { vm.filter = .text }
                PillButton(title: "Images", selected: vm.filter == .images) { vm.filter = .images }
            }

            Button(action: onCycleLayout) {
                Image(systemName: layoutIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}
