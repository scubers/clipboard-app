import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var state = SharedAppState.shared

    @State private var privacyMode: Bool = false
    @State private var retentionMax: Int = 500
    @State private var stats: Stats?
    @State private var error: String?
    @State private var showRestartPrompt: Bool = false

    var body: some View {
        Form {
            Section("Storage") {
                HStack {
                    Text("Local config")
                    Spacer()
                    Text(AppPaths.localBaseDir.path)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack {
                    Text("Shared data directory")
                    Spacer()
                    Text(state.sharedDataDir)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    Button("Choose…") {
                        let p = NSOpenPanel()
                        p.canChooseFiles = false
                        p.canChooseDirectories = true
                        p.allowsMultipleSelection = false
                        p.prompt = "Use This Folder"
                        p.message = "Choose a folder to store shared config & data. Put it in a cloud-synced folder (e.g. iCloud Drive) to sync across devices."
                        p.directoryURL = URL(fileURLWithPath: state.sharedDataDir, isDirectory: true)

                        if p.runModal() == .OK, let url = p.url {
                            do {
                                try state.reloadSharedDataDir(url.path)
                                showRestartPrompt = true
                            } catch {
                                self.error = String(describing: error)
                            }
                        }
                    }

                    Button("Reset") {
                        do {
                            // Reset by saving default path.
                            try AppPaths.setSharedDir(AppPaths.defaultSharedBaseDir)
                            try state.reloadSharedDataDir(AppPaths.defaultSharedBaseDir.path)
                            showRestartPrompt = true
                        } catch {
                            self.error = String(describing: error)
                        }
                    }

                    Spacer()

                    Button("Open Shared Folder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: state.sharedDataDir, isDirectory: true))
                    }
                }

                Text("Tip: set Shared data directory to a cloud-synced folder to enable cross-device sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HotkeySettingsView()
            ExportImportView()

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { LaunchAtLoginManager.shared.enabled },
                    set: { newValue in
                        Task { @MainActor in
                            do {
                                try LaunchAtLoginManager.shared.setEnabled(newValue)
                            } catch {
                                self.error = "Launch at login failed: \(error)" 
                                LaunchAtLoginManager.shared.refresh()
                            }
                        }
                    }
                ))

                Text("Note: may require the app to be code-signed and installed (e.g., in /Applications) to work reliably.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Capture") {
                Toggle("Privacy Mode (stop capturing new items)", isOn: $privacyMode)
                    .onChange(of: privacyMode) { _, newValue in
                        do {
                            try state.core.setPrivacyMode(newValue)
                        } catch {
                            self.error = String(describing: error)
                        }
                    }

                Stepper(value: $retentionMax, in: 10...100000, step: 10) {
                    Text("Retention max items: \(retentionMax)")
                }
                .onChange(of: retentionMax) { _, newValue in
                    do {
                        try state.core.setRetentionMax(newValue)
                    } catch {
                        self.error = String(describing: error)
                    }
                }

                Button("Optimize DB") {
                    Task {
                        do { try state.core.optimize() } catch { self.error = String(describing: error) }
                    }
                }

                Button("Integrity Check") {
                    Task {
                        do {
                            let r = try state.core.integrityCheck()
                            if !r.ok {
                                self.error = "Integrity check failed: \(r.message)"
                            } else {
                                self.error = nil
                            }
                        } catch {
                            self.error = String(describing: error)
                        }
                    }
                }

                Button("Vacuum DB") {
                    Task {
                        do { try state.core.vacuum() } catch { self.error = String(describing: error) }
                    }
                }

                Button("Clear History (soft delete, keep pinned)") {
                    Task {
                        do { try state.core.clearAll(keepPinned: true) } catch { self.error = String(describing: error) }
                        await refreshStats()
                    }
                }

                Button("Remove History (physical delete, keep pinned)") {
                    let alert = NSAlert()
                    alert.messageText = "Permanently remove history?"
                    alert.informativeText = "This will physically delete history rows from the database (keeping pinned items). It will also remove any stored blob files for non-text items. This cannot be undone."
                    alert.addButton(withTitle: "Remove")
                    alert.addButton(withTitle: "Cancel")
                    if alert.runModal() == .alertFirstButtonReturn {
                        Task {
                            do { try state.core.removeHistory(keepPinned: true) } catch { self.error = String(describing: error) }
                            await refreshStats()
                        }
                    }
                }

                Button("Remove History (physical delete, include pinned)") {
                    let alert = NSAlert()
                    alert.messageText = "Permanently remove ALL history?"
                    alert.informativeText = "This will physically delete ALL rows from the database, including pinned items, and remove blob files. This cannot be undone."
                    alert.addButton(withTitle: "Remove All")
                    alert.addButton(withTitle: "Cancel")
                    if alert.runModal() == .alertFirstButtonReturn {
                        Task {
                            do { try state.core.removeHistory(keepPinned: false) } catch { self.error = String(describing: error) }
                            await refreshStats()
                        }
                    }
                }
            }

            Section("Stats") {
                if let stats {
                    LabeledContent("Total", value: "\(stats.totalItems)")
                    LabeledContent("Active", value: "\(stats.activeItems)")
                    LabeledContent("Deleted", value: "\(stats.deletedItems)")
                    LabeledContent("Pinned active", value: "\(stats.pinnedActiveItems)")
                } else {
                    Text("(No stats yet)")
                        .foregroundStyle(.secondary)
                }

                Button("Refresh stats") { Task { await refreshStats() } }
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(16)
        .frame(width: 560)
        .task {
            await bootstrap()
        }
        .alert("Restart Required", isPresented: $showRestartPrompt) {
            Button("Restart") {
                AppRelauncher.restart()
            }
            Button("Later", role: .cancel) {
                // no-op
            }
        } message: {
            Text("The shared data directory has changed. Please restart the app to ensure all components use the new location.")
        }
    }

    private func bootstrap() async {
        do {
            privacyMode = try state.core.getPrivacyMode()
            retentionMax = try state.core.getRetentionMax()
            await refreshStats()
        } catch {
            self.error = String(describing: error)
        }
    }

    private func refreshStats() async {
        do {
            stats = try state.core.stats()
        } catch {
            self.error = String(describing: error)
        }
    }
}
