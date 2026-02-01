import SwiftUI

struct ShortcutsSettingsPage: View {
    @ObservedObject var hk: HotkeyManager
    @Binding var isRecordingHotkey: Bool
    @ObservedObject var hotkeyCapture: HotkeyCapture

    let currentHotkeyDisplay: () -> String
    let startHotkeyCapture: () -> Void
    let stopHotkeyCapture: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Global hotkey") {
                SettingsRow(title: "Toggle popover") {
                    HStack(spacing: 10) {
                        Text(currentHotkeyDisplay())
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                            .foregroundStyle(.secondary)

                        Button("Change…") {
                            startHotkeyCapture()
                        }
                        .disabled(isRecordingHotkey)
                    }
                }
                Text("Click Change… then press a new key combination.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if isRecordingHotkey {
                SettingsCard(title: "Recording") {
                    SettingsRow(title: "Recording…") {
                        HStack(spacing: 10) {
                            Text(hotkeyCapture.status)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                                .overlay(Capsule().stroke(Color.accentColor.opacity(0.25), lineWidth: 1))

                            Button("Cancel") {
                                stopHotkeyCapture()
                            }
                        }
                    }
                    Text("Press Esc to cancel. Press Backspace to clear.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            SettingsCard(title: "Behavior") {
                SettingsRow(title: "Enter key") {
                    Text("Paste")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                        .foregroundStyle(.secondary)
                }
                Text("Press Enter to paste the selected item into the previous app.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if !hk.enabled {
                hk.enabled = true
                hk.refreshRegistration()
            }
        }
    }
}
