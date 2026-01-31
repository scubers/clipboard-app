import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var state = SharedAppState.shared

    @State private var privacyMode: Bool = false
    @State private var retentionMax: Int = 500
    @State private var stats: Stats?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Storage") {
                HStack {
                    Text("Data directory")
                    Spacer()
                    Text(ClipboardViewModel.defaultDataDir)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button("Open Data Folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: ClipboardViewModel.defaultDataDir, isDirectory: true))
                }
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

                Button("Clear History (keep pinned)") {
                    Task {
                        do { try state.core.clearAll(keepPinned: true) } catch { self.error = String(describing: error) }
                        await refreshStats()
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
