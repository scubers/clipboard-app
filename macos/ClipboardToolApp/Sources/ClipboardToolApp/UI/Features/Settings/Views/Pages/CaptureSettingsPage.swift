import SwiftUI

struct CaptureSettingsPage: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Privacy") {
                SettingsRow(title: "Privacy mode") {
                    Toggle("", isOn: $vm.privacyMode)
                        .labelsHidden()
                        .onChange(of: vm.privacyMode) { _, newValue in
                            vm.setPrivacyMode(newValue)
                        }
                }
                Text("When enabled, the app stops capturing new clipboard items.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            SettingsCard(title: "Retention") {
                SettingsRow(title: "Max items") {
                    HStack(spacing: 10) {
                        Slider(value: Binding(
                            get: { Double(vm.retentionMax) },
                            set: { vm.retentionMax = Int($0.rounded()); vm.setRetentionMax(vm.retentionMax) }
                        ), in: 10...100000)

                        Text("\(vm.retentionMax)")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 360)
                }
            }
        }
    }
}
