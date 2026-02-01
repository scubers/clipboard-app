import SwiftUI

struct GeneralSettingsPage: View {
    @ObservedObject var store: AppStore
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Startup") {
                SettingsRow(title: "Launch at login") {
                    Toggle("", isOn: Binding(
                        get: { LaunchAtLoginManager.shared.enabled },
                        set: { newValue in
                            Task { @MainActor in
                                vm.toggleLaunchAtLogin(newValue)
                            }
                        }
                    ))
                    .labelsHidden()
                }
            }

            SettingsCard(title: "Monitoring") {
                SettingsRow(title: "Enable monitoring") {
                    Toggle("", isOn: $store.monitoringEnabled)
                        .labelsHidden()
                }

                SettingsRow(title: "Poll interval") {
                    HStack(spacing: 10) {
                        Slider(value: Binding(
                            get: { store.pollIntervalMs },
                            set: { store.pollIntervalMs = $0; store.applyPollInterval() }
                        ), in: 100...2000)
                        Text("\(Int(store.pollIntervalMs))ms")
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

            SettingsCard(title: "Layout") {
                SettingsRow(title: "Default preview layout") {
                    Picker("", selection: $store.previewLayout) {
                        Text("L").tag(PreviewLayout.previewLeft)
                        Text("R").tag(PreviewLayout.previewRight)
                        Text("B").tag(PreviewLayout.previewBottom)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                Text("Popover cycles layouts in the order: R → L → B.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
