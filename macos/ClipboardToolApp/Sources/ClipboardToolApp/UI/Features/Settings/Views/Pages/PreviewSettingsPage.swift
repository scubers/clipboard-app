import SwiftUI

struct PreviewSettingsPage: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Text") {
                SettingsRow(title: "Wrap") {
                    Toggle("", isOn: $store.previewWrap)
                        .labelsHidden()
                }
                SettingsRow(title: "Monospace") {
                    Toggle("", isOn: $store.previewMonospace)
                        .labelsHidden()
                }
            }

            SettingsCard(title: "Images") {
                SettingsRow(title: "Fit mode") {
                    Text("Scale to fit")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
