import SwiftUI

struct HotkeySettingsView: View {
    @StateObject private var hk = HotkeyManager.shared

    @State private var showRecorder = false

    var body: some View {
        Section("Hotkey") {
            Toggle("Enable global hotkey", isOn: $hk.enabled)
                .onChange(of: hk.enabled) { _, _ in
                    hk.refreshRegistration()
                }

            Picker("Preset", selection: $hk.hotkeyId) {
                ForEach(hk.availableHotkeys(), id: \.self) { id in
                    Text(displayName(id)).tag(id)
                }
            }
            .onChange(of: hk.hotkeyId) { _, _ in
                hk.useCustom = false
                hk.refreshRegistration()
            }

            Toggle("Use custom recorded hotkey", isOn: $hk.useCustom)
                .onChange(of: hk.useCustom) { _, _ in
                    hk.refreshRegistration()
                }

            HStack {
                Button("Record…") { showRecorder = true }
                Spacer()
                Text(hk.customDisplay.isEmpty ? "(none)" : hk.customDisplay)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("Tip: include at least one modifier. The app must be running for the hotkey to work.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showRecorder) {
            HotkeyRecorder { keyCode, mods, display in
                hk.setCustom(keyCode: keyCode, carbonModifiers: mods, display: display)
            }
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
