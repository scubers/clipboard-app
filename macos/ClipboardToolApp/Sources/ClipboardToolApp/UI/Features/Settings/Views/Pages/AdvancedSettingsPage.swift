import AppKit
import SwiftUI

struct AdvancedSettingsPage: View {
    @ObservedObject var vm: SettingsViewModel

    let exportToFolder: () -> Void
    let importFromFolder: () -> Void
    let removeHistory: (_ keepPinned: Bool) -> Void

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Database") {
                SettingsRow(title: "Optimize / Vacuum") {
                    HStack(spacing: 10) {
                        Button("Optimize") { Task { await vm.runOptimize() } }
                        Button("Vacuum") { Task { await vm.runVacuum() } }
                    }
                }
                SettingsRow(title: "Integrity check") {
                    Button("Run") { Task { await vm.runIntegrityCheck() } }
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
                        Button("Remove (keep pinned)") { removeHistory(true) }
                            .foregroundStyle(.red)
                        Button("Remove all") { removeHistory(false) }
                            .foregroundStyle(.red)
                    }
                }
                Text("These actions permanently delete database rows and blob files.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
