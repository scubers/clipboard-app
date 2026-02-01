import AppKit
import SwiftUI

struct StorageSettingsPage: View {
    @ObservedObject var store: AppStore
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
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
                        Button("Reset") { vm.resetSharedDirToDefault() }
                        Button("Open") { vm.openSharedDirInFinder() }
                    }
                }
            }

            SettingsCard(title: "Restart") {
                SettingsRow(title: "Required after change") {
                    HStack(spacing: 10) {
                        Button("Restart Now") { AppRelauncher.restart() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                Text("Changing the shared directory requires restarting the app to ensure all components use the new location.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

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
}
