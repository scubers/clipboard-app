import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var store = AppStore.shared
    @StateObject private var vm = SettingsViewModel()
    @StateObject private var hk = HotkeyManager.shared

    @State private var selection: SettingsPage = .general

    // Shortcuts recording
    @State private var isRecordingHotkey: Bool = false
    @StateObject private var hotkeyCapture = HotkeyCapture()

    private let sidebarWidth: CGFloat = 240

    var body: some View {
        ZStack {
            // Tune the hosting window chrome so the titlebar background matches our glass.
            WindowChromeTuner()
                .frame(width: 0, height: 0)

            // Match popover: frosted glass + tint overlay.
            VisualEffectMaterial(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()

            Rectangle()
                .fill(Color.black.opacity(store.backgroundTint))
                .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                    .frame(width: sidebarWidth)

                Divider()
                    .opacity(0.35)

                content
            }
        }
        .frame(width: 940, height: 620)
        .task {
            await vm.bootstrap()
        }
        .onChange(of: selection) { _, _ in
            stopHotkeyCapture()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preferences")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                ForEach(SettingsPage.allCases) { page in
                    SettingsSidebarRow(
                        title: page.rawValue,
                        systemImage: page.icon,
                        selected: selection == page
                    ) {
                        selection = page
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 10)
        }
        .background(Color.primary.opacity(0.04))
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsHeader(title: selection.rawValue, subtitle: selection.subtitle)

                switch selection {
                case .general:
                    generalPage
                case .appearance:
                    appearancePage
                case .preview:
                    previewPage
                case .storage:
                    storagePage
                case .shortcuts:
                    shortcutsPage
                case .capture:
                    capturePage
                case .advanced:
                    advancedPage
                }

                if let error = vm.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }

                Spacer(minLength: 12)
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
    }

    // MARK: - Pages

    private var generalPage: some View {
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

    private var appearancePage: some View {
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

    private var previewPage: some View {
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

    private var storagePage: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Directories") {
                SettingsRow(title: "Local config") {
                    SettingsPathText(path: AppPaths.localBaseDir.path)
                }
                SettingsRow(title: "Shared directory") {
                    SettingsPathText(path: store.sharedDataDir)
                }
                SettingsRow(title: "Actions") {
                    HStack(spacing: 10) {
                        Button("Choose…") { chooseSharedDir() }
                        Button("Reset") { resetSharedDir() }
                        Button("Open") { openSharedDir() }
                    }
                }
            }

            SettingsCard(title: "Restart") {
                SettingsRow(title: "Required after change") {
                    HStack(spacing: 10) {
                        Button("Restart Now") { AppRelauncher.restart() }
                            .buttonStyle(.borderedProminent)
                        Button("Not Now") { /* no-op */ }
                            .buttonStyle(.bordered)
                    }
                }
                Text("Changing the shared directory requires restarting the app to ensure all components use the new location.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shortcutsPage: some View {
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
            // Spec does not expose an enable toggle; ensure it is on.
            if !hk.enabled {
                hk.enabled = true
                hk.refreshRegistration()
            }
        }
    }

    private var capturePage: some View {
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

    private var advancedPage: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Database") {
                SettingsRow(title: "Optimize / Vacuum") {
                    HStack(spacing: 10) {
                        Button("Optimize") { Task { await runOptimize() } }
                        Button("Vacuum") { Task { await runVacuum() } }
                    }
                }
                SettingsRow(title: "Integrity check") {
                    Button("Run") { Task { await runIntegrityCheck() } }
                }
            }

            SettingsCard(title: "Transfer") {
                SettingsRow(title: "Export") {
                    Button("Export…") { exportToFolder() }
                }
                SettingsRow(title: "Import") {
                    HStack(spacing: 10) {
                        Button("Import…") { importFromFolder() }
                        Text("Keep backup")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SettingsCard(title: "Danger zone") {
                SettingsRow(title: "Remove history") {
                    HStack(spacing: 10) {
                        Button("Remove (keep pinned)") { removeHistory(keepPinned: true) }
                            .foregroundStyle(.red)
                        Button("Remove all") { removeHistory(keepPinned: false) }
                            .foregroundStyle(.red)
                    }
                }
                Text("These actions permanently delete database rows and blob files.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    // bootstrap moved to SettingsViewModel

    // setRetentionMax moved to SettingsViewModel

    private func chooseSharedDir() {
        let p = NSOpenPanel()
        p.canChooseFiles = false
        p.canChooseDirectories = true
        p.allowsMultipleSelection = false
        p.prompt = "Use This Folder"
        p.directoryURL = URL(fileURLWithPath: store.sharedDataDir, isDirectory: true)

        if p.runModal() == .OK, let url = p.url {
            vm.reloadSharedDataDir(url.path)
        }
    }

    private func resetSharedDir() {
        vm.resetSharedDirToDefault()
    }

    private func openSharedDir() {
        vm.openSharedDirInFinder()
    }

    private func currentHotkeyDisplay() -> String {
        if hk.useCustom, !hk.customDisplay.isEmpty {
            return hk.customDisplay
        }
        return hk.hotkeyId
            .replacingOccurrences(of: "cmd", with: "⌘")
            .replacingOccurrences(of: "shift", with: "⇧")
            .replacingOccurrences(of: "opt", with: "⌥")
            .replacingOccurrences(of: "ctrl", with: "⌃")
            .replacingOccurrences(of: "space", with: "Space")
            .replacingOccurrences(of: "+", with: " ")
            .uppercased()
    }

    private func startHotkeyCapture() {
        isRecordingHotkey = true
        hotkeyCapture.status = "Press keys now"

        hotkeyCapture.start(onCaptured: { keyCode, mods, display in
            if keyCode == 0 {
                self.hk.setCustom(keyCode: 0, carbonModifiers: 0, display: "")
                self.isRecordingHotkey = false
                self.hotkeyCapture.stop()
                return
            }
            self.hk.setCustom(keyCode: keyCode, carbonModifiers: mods, display: display)
            self.isRecordingHotkey = false
            self.hotkeyCapture.stop()
        }, onCancel: {
            self.isRecordingHotkey = false
            self.hotkeyCapture.stop()
        })
    }

    private func stopHotkeyCapture() {
        isRecordingHotkey = false
        hotkeyCapture.stop()
    }

    private func runOptimize() async { await vm.runOptimize() }

    private func runVacuum() async { await vm.runVacuum() }

    private func runIntegrityCheck() async { await vm.runIntegrityCheck() }

    private func exportToFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        if panel.runModal() == .OK, let url = panel.url {
            vm.exportToDir(url.path)
        }
    }

    private func importFromFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        if panel.runModal() == .OK, let url = panel.url {
            let alert = NSAlert()
            alert.messageText = "Import clipboard database?"
            alert.informativeText = "This will replace your current history. A backup of existing files will be kept."
            alert.addButton(withTitle: "Import")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                vm.importFromDir(url.path, keepBackup: true)
            }
        }
    }

    private func removeHistory(keepPinned: Bool) {
        let alert = NSAlert()
        alert.messageText = keepPinned ? "Permanently remove history?" : "Permanently remove ALL history?"
        alert.informativeText = "This will physically delete database rows and blob files. This cannot be undone."
        alert.addButton(withTitle: keepPinned ? "Remove" : "Remove All")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            Task { @MainActor in
                await vm.removeHistory(keepPinned: keepPinned)
            }
        }
    }
}

private struct SettingsSidebarRow: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.10), lineWidth: 1))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? Color.accentColor.opacity(0.22) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(selected ? 0.22 : 0.0), lineWidth: 1)
            )
            // Make the whole visible row clickable (including blank space).
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? .primary : .secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
