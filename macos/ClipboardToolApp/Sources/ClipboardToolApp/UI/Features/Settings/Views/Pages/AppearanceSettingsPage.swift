import SwiftUI

struct AppearanceSettingsPage: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Background") {
                SettingsRow(title: "Tint (readability)") {
                    HStack(spacing: 10) {
                        Slider(value: $store.backgroundTint, in: 0.02...0.80)
                        Text(String(format: "%.0f%%", store.backgroundTint * 100))
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 360)
                }
                Text("Higher tint improves text readability on bright backgrounds.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            SettingsCard(title: "Window") {
                SettingsRow(title: "Hide traffic lights") {
                    Toggle("", isOn: $store.hideTrafficLights)
                        .labelsHidden()
                }
                Text("Keeps the popover visually minimal (Raycast-like).")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
