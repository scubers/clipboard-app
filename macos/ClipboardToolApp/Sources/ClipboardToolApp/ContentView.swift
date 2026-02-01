import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ClipboardViewModel()
    @StateObject private var appState = SharedAppState.shared

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

            VStack(spacing: 10) {
                // Search row (no title bar in content)
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "command")
                            .foregroundStyle(.secondary)
                        TextField("Search clipboard…", text: $vm.query)
                            .textFieldStyle(.plain)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.10), lineWidth: 1))

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
                Group {
                    switch appState.previewLayout {
                    case .previewRight:
                        HStack(spacing: 12) {
                            listPane
                            previewPane
                                .frame(width: 300)
                        }
                    case .previewLeft:
                        HStack(spacing: 12) {
                            previewPane
                                .frame(width: 300)
                            listPane
                        }
                    case .previewBottom:
                        VStack(spacing: 12) {
                            listPane
                            previewPane
                                .frame(height: 190)
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
            // Restore last viewed item (and scroll to it) on each open.
            if vm.selectedID == nil {
                vm.selectedID = vm.filteredItems.first?.id
            }
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

    private var listPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.filteredItems) { item in
                        ItemRowView(item: item, selected: vm.selectedID == item.id)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                vm.selectedID = item.id
                                focus = .list
                            }
                    }
                }
                .padding(2)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .onChange(of: vm.selectedID) { _, newValue in
                guard let id = newValue else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .clipboardToolFocusSearch)) { _ in
                // When reopening, restore to last selected item (our proxy for scroll position).
                if let id = vm.selectedID {
                    DispatchQueue.main.async {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .focused($focus, equals: .list)
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Wrap", isOn: $vm.previewWrap)
                    .toggleStyle(.switch)
                Toggle("Mono", isOn: $vm.previewMonospace)
                    .toggleStyle(.switch)
                Spacer()
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            PreviewCardView(vm: vm)
        }
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
