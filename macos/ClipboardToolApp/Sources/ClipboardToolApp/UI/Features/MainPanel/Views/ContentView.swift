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
                // Search row (no title bar in content)
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("Search clipboard…", text: $vm.query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .semibold))
                            .focused($focus, equals: .search)
                            .onSubmit { vm.refresh() }
                            .onKeyPress(.downArrow) {
                                focus = .list
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

                    Button {
                        appState.previewLayout = appState.previewLayout.next
                    } label: {
                        Image(systemName: layoutIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Layout: \(appState.previewLayout.title) (cycle R → L → B)")
                }

                if let err = vm.error {
                    Text(err)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Body
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
                        switch appState.previewLayout {
                        case .previewRight:
                            HStack(spacing: spacing) {
                                listPane
                                    .frame(width: listW)
                                previewPane
                                    .frame(width: previewW)
                            }
                        case .previewLeft:
                            HStack(spacing: spacing) {
                                previewPane
                                    .frame(width: previewW)
                                listPane
                                    .frame(width: listW)
                            }
                        case .previewBottom:
                            VStack(spacing: spacing) {
                                listPane
                                    .frame(height: listH)
                                previewPane
                                    .frame(height: previewH)
                            }
                        }
                    }
                }

                footer
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

    private struct RowFrameKey: PreferenceKey {
        static var defaultValue: [String: CGRect] = [:]
        static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }

    private var listPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.filteredItems) { item in
                        ItemRowView(item: item, selected: vm.selectedID == item.id)
                            .id(item.id)
                            .contentShape(Rectangle())
                            // Single click should respond immediately.
                            // We implement double-click detection ourselves to avoid SwiftUI's
                            // single-tap delay when also using onTapGesture(count: 2).
                            .onTapGesture {
                                let now = Date()
                                vm.selectedID = item.id
                                focus = .list

                                if let lastID = lastClickID,
                                   let lastAt = lastClickAt,
                                   lastID == item.id,
                                   now.timeIntervalSince(lastAt) < 0.32 {
                                    // Treat as double click.
                                    lastClickID = nil
                                    lastClickAt = nil
                                    vm.pasteSelectedToPreviousApp()
                                } else {
                                    lastClickID = item.id
                                    lastClickAt = now
                                }
                            }
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
                guard let id = newValue else { return }
                // Only scroll when the selected row is not currently visible.
                guard !visibleIDs.contains(id) else {
                    lastSelectedID = id
                    return
                }

                // Decide direction using old/new indices if possible.
                let newIdx = vm.filteredItems.firstIndex(where: { $0.id == id })
                let oldIdx = (oldValue != nil) ? vm.filteredItems.firstIndex(where: { $0.id == oldValue! }) : nil

                let movingDown: Bool
                if let n = newIdx, let o = oldIdx {
                    movingDown = n > o
                } else {
                    // Fallback: compare against lastSelectedID
                    if let last = lastSelectedID,
                       let n = newIdx,
                       let o = vm.filteredItems.firstIndex(where: { $0.id == last }) {
                        movingDown = n > o
                    } else {
                        movingDown = true
                    }
                }

                // Defer one tick so visibleIDs updates settle.
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.10)) {
                        proxy.scrollTo(id, anchor: movingDown ? .bottom : .top)
                    }
                }
                lastSelectedID = id
            }
            .onReceive(NotificationCenter.default.publisher(for: .clipboardToolFocusSearch)) { _ in
                // Per spec: jump to top on each activation.
                if let first = vm.filteredItems.first?.id {
                    DispatchQueue.main.async {
                        proxy.scrollTo(first, anchor: .top)
                    }
                }
            }
        }
        .focused($focus, equals: .list)
    }

    @State private var visibleIDs: Set<String> = []
    @State private var lastSelectedID: String?

    // For manual double-click detection (to keep single-click instantaneous).
    @State private var lastClickID: String?
    @State private var lastClickAt: Date?

    private var previewPane: some View {
        PreviewCardView(vm: vm, wrap: appState.previewWrap, monospace: appState.previewMonospace)
    }

    private var footer: some View {
        HStack {
            Text("↑↓ select · ⌘↵ paste · ⌘C copy")
            Spacer()
            Text("\(vm.filteredItems.count) items")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }
}
