import SwiftUI

struct HotkeySettingsView: View {
    @StateObject private var hk = HotkeyManager.shared

    var body: some View {
        Section("Hotkey") {
            Toggle("Enable global hotkey", isOn: $hk.enabled)
                .onChange(of: hk.enabled) { _, _ in
                    hk.refreshRegistration()
                }

            Picker("Hotkey", selection: $hk.hotkeyId) {
                ForEach(hk.availableHotkeys(), id: \.self) { id in
                    Text(displayName(id)).tag(id)
                }
            }
            .onChange(of: hk.hotkeyId) { _, _ in
                hk.refreshRegistration()
            }

            Text("No default hotkey required. Pick one and enable it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func displayName(_ id: String) -> String {
        id
            .replacingOccurrences(of: "cmd", with: "⌘")
            .replacingOccurrences(of: "shift", with: "⇧")
            .replacingOccurrences(of: "opt", with: "⌥")
            .replacingOccurrences(of: "ctrl", with: "⌃")
            .replacingOccurrences(of: "space", with: "Space")
            .replacingOccurrences(of: "+", with: " ")
            .uppercased()
    }
}
