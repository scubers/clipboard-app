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
                    GeneralSettingsPage(store: store, vm: vm)
                case .appearance:
                    AppearanceSettingsPage(store: store)
                case .preview:
                    PreviewSettingsPage(store: store)
                case .storage:
                    StorageSettingsPage(store: store, vm: vm)
                case .shortcuts:
                    ShortcutsSettingsPage(
                        hk: hk,
                        isRecordingHotkey: $isRecordingHotkey,
                        hotkeyCapture: hotkeyCapture,
                        currentHotkeyDisplay: currentHotkeyDisplay,
                        startHotkeyCapture: startHotkeyCapture,
                        stopHotkeyCapture: stopHotkeyCapture
                    )
                case .capture:
                    CaptureSettingsPage(vm: vm)
                case .advanced:
                    AdvancedSettingsPage(
                        vm: vm,
                        exportToFolder: exportToFolder,
                        importFromFolder: importFromFolder,
                        removeHistory: removeHistory
                    )
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

    // MARK: - Helpers

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

    private func removeHistory(_ keepPinned: Bool) {
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

// SettingsSidebarRow moved to Views/Components/SettingsSidebarRow.swift
