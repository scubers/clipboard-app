import AppKit
import SwiftUI

struct PreviewCardView: View {
    @ObservedObject var vm: ClipboardViewModel

    private var selectedItem: Item? {
        guard let id = vm.selectedID else { return nil }
        return vm.filteredItems.first(where: { $0.id == id })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preview")
                        .font(.system(size: 13.5, weight: .semibold))

                    if let item = selectedItem {
                        let dt = Date(timeIntervalSince1970: Double(item.lastCopiedAtMs) / 1000)
                        HStack(spacing: 6) {
                            Text(item.sourceApp ?? "(Unknown)")
                            Text("·")
                            Text(dt.formatted(.relative(presentation: .named)))
                            if item.pinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    } else {
                        Text("(No selection)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let item = selectedItem, item.pinned {
                    Text("Pinned")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                        .foregroundStyle(.secondary)
                }
            }

            Group {
                if vm.previewImage != nil {
                    ScrollView([.vertical, .horizontal]) {
                        if let img = vm.previewImage {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                    }
                } else {
                    ScrollView([.vertical, vm.previewWrap ? [] : .horizontal]) {
                        Text(vm.previewText)
                            .font(vm.previewMonospace ? .system(.body, design: .monospaced) : .body)
                            .frame(maxWidth: vm.previewWrap ? .infinity : nil, alignment: .leading)
                            .fixedSize(horizontal: !vm.previewWrap, vertical: true)
                            .textSelection(.enabled)
                            .padding(.vertical, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                Button("Copy") { vm.copySelectedToPasteboard() }
                    .keyboardShortcut("c", modifiers: [.command])
                    .disabled(vm.selectedID == nil)

                Button("Paste") { vm.pasteSelectedToPreviousApp() }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.selectedID == nil)

                // Press Enter to paste (invisible button)
                Button("", action: { vm.pasteSelectedToPreviousApp() })
                    .keyboardShortcut(.return, modifiers: [])
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .disabled(vm.selectedID == nil)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }
}
