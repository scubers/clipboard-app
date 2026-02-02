import SwiftUI

struct MainPanelListPane: View {
    @ObservedObject var vm: MainPanelViewModel
    let focus: FocusState<ContentView.FocusTarget?>.Binding

    @Binding var visibleIDs: Set<String>
    @Binding var lastSelectedID: String?

    // For manual double-click detection (to keep single-click instantaneous).
    @Binding var lastClickID: String?
    @Binding var lastClickAt: Date?

    var body: some View {
        let items = vm.filteredItems

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        ItemRowView(item: item, selected: vm.selectedID == item.id)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { handleRowTap(itemID: item.id) }
                            .onAppear { visibleIDs.insert(item.id) }
                            .onDisappear { visibleIDs.remove(item.id) }
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
