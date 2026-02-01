import AppKit
import SwiftUI

struct ExportImportView: View {
    @StateObject private var state = SharedAppState.shared
    @State private var error: String?

    var body: some View {
        Section("Export / Import") {
            Button("Export to Folder…") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                panel.canCreateDirectories = true
                panel.prompt = "Export"
                if panel.runModal() == .OK, let url = panel.url {
                    do {
                        try export(to: url)
                    } catch {
                        self.error = String(describing: error)
                    }
                }
            }

            Button("Import from Folder…") {
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
                        do {
                            try importFrom(url: url)
                        } catch {
                            self.error = String(describing: error)
                        }
                    }
                }
            }

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private func export(to url: URL) throws {
        try state.core.exportToDir(url.path)
    }

    private func importFrom(url: URL) throws {
        try state.core.importFromDir(url.path, keepBackup: true)
        state.notifyDataSourceChanged()
    }
}
