import AppKit
import SwiftUI

struct PreviewCardView: View {
    @ObservedObject var vm: MainPanelViewModel
    let wrap: Bool
    let monospace: Bool
    let onDelete: () -> Void

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
                if let img = vm.previewImage {
                    // Show full image without scroll; scale-to-fit while keeping aspect ratio.
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 6)
                } else {
                    ScrollView([.vertical, wrap ? [] : .horizontal]) {
                        Text(vm.previewText)
                            .font(monospace ? .system(.body, design: .monospaced) : .body)
                            .frame(maxWidth: wrap ? .infinity : nil, alignment: .leading)
                            .fixedSize(horizontal: !wrap, vertical: true)
                            .textSelection(.enabled)
                            .padding(.vertical, 6)
                    }
                    .scrollIndicators(.automatic)
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

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(vm.selectedID == nil)
                .help("Delete item")

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
