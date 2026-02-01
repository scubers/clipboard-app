import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ClipboardViewModel()
    @FocusState private var focus: FocusTarget?

    enum FocusTarget {
        case search
        case list
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search", text: $vm.query)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .search)
                    .onSubmit { vm.refresh() }
                    .onKeyPress(.downArrow) {
                        // Move focus to list and select first item for keyboard-only workflow.
                        focus = .list
                        if vm.selectedID == nil {
                            vm.selectedID = vm.items.first?.id
                        }
                        return .handled
                    }

                Button("Refresh") { vm.refresh() }
            }

            HStack {
                Toggle("Monitor", isOn: $vm.monitoringEnabled)
                    .toggleStyle(.switch)

                Spacer()

                Text("Poll (ms)")
                TextField("500", value: $vm.pollIntervalMs, format: .number)
                    .frame(width: 72)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { vm.applyPollInterval() }

                Button("Apply") { vm.applyPollInterval() }
            }

            if let err = vm.error {
                Text(err)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                List(vm.items, selection: $vm.selectedID) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text((item.type == "image" ? "[img] " : "") + item.summary).lineLimit(2)
                        Text(Date(timeIntervalSince1970: Double(item.lastCopiedAtMs) / 1000).formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .focused($focus, equals: .list)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Preview")
                            .font(.headline)
                        Spacer()
                        Toggle("Wrap", isOn: $vm.previewWrap)
                        Toggle("Mono", isOn: $vm.previewMonospace)
                    }

                    if let img = vm.previewImage {
                        ScrollView([.vertical, .horizontal]) {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                        }
                    } else {
                        ScrollView([.vertical, vm.previewWrap ? [] : .horizontal]) {
                            Text(vm.previewText)
                                .font(vm.previewMonospace ? .system(.body, design: .monospaced) : .body)
                                .frame(maxWidth: vm.previewWrap ? .infinity : nil, alignment: .leading)
                                .fixedSize(horizontal: !vm.previewWrap, vertical: true)
                                .textSelection(.enabled)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                        }
                    }

                    Spacer()

                    HStack {
                        Button("Copy") { vm.copySelectedToPasteboard() }
                            .disabled(vm.selectedID == nil)
                            .keyboardShortcut("c", modifiers: [.command])

                        // Press Enter to copy + paste into the previous app
                        Button("", action: { vm.pasteSelectedToPreviousApp() })
                            .keyboardShortcut(.return, modifiers: [])
                            .opacity(0)
                            .frame(width: 0, height: 0)
                            .disabled(vm.selectedID == nil)

                        Button("Add Test") { vm.addTestItem() }
                    }
                }
                .frame(width: 280)
            }
        }
        .padding(12)
        .onAppear {
            vm.bootstrap()
            focus = .search
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardToolFocusSearch)) { _ in
            focus = .search
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardToolItemsChanged)) { _ in
            // Keep list live if the user isn't actively searching.
            if vm.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                vm.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardToolStorageChanged)) { _ in
            // Switching shared data dir should always refresh (even while searching).
            vm.refresh()
        }
        .onChange(of: vm.selectedID) { _, _ in
            vm.loadPreview()
        }
    }
}
