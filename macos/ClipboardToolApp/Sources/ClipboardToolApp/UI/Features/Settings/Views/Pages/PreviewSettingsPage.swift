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

        }
    }
}
