import AppKit
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    private let store: AppStore
    private var repo: ClipboardRepository { store.clipboardRepo }

    @Published var privacyMode: Bool = false
    @Published var retentionMax: Int = 500
    @Published var error: String?

    init(store: AppStore) {
        self.store = store
    }

    convenience init() {
        self.init(store: .shared)
    }

    func bootstrap() async {
        do {
            privacyMode = try repo.getPrivacyMode()
            retentionMax = try repo.getRetentionMax()
        } catch {
            self.error = String(describing: error)
        }
    }

    func setPrivacyMode(_ enabled: Bool) {
        do {
            try repo.setPrivacyMode(enabled)
        } catch {
            self.error = String(describing: error)
        }
    }

    func setRetentionMax(_ v: Int) {
        do {
            try repo.setRetentionMax(v)
        } catch {
            self.error = String(describing: error)
        }
    }

    func runOptimize() async {
        do { try repo.optimize() } catch { self.error = String(describing: error) }
    }

    func runVacuum() async {
        do { try repo.vacuum() } catch { self.error = String(describing: error) }
    }

    func runIntegrityCheck() async {
        do {
            let r = try repo.integrityCheck()
            if !r.ok {
                self.error = "Integrity check failed: \(r.message)"
            } else {
                self.error = nil
            }
        } catch {
            self.error = String(describing: error)
        }
    }

    func exportToDir(_ path: String) {
        do {
            try repo.exportToDir(path)
        } catch {
            self.error = String(describing: error)
        }
    }

    func importFromDir(_ path: String, keepBackup: Bool) {
        do {
            try repo.importFromDir(path, keepBackup: keepBackup)
            store.notifyDataSourceChanged()
        } catch {
            self.error = String(describing: error)
        }
    }

    func removeHistory(keepPinned: Bool) async {
        do {
            try repo.removeHistory(keepPinned: keepPinned)
            store.notifyDataSourceChanged()
        } catch {
            self.error = String(describing: error)
        }
    }

    func reloadSharedDataDir(_ newDir: String) {
        do {
            try store.reloadSharedDataDir(newDir)
        } catch {
            self.error = String(describing: error)
        }
    }

    func resetSharedDirToDefault() {
        do {
            try AppPaths.setSharedDir(AppPaths.defaultSharedBaseDir)
            try store.reloadSharedDataDir(AppPaths.defaultSharedBaseDir.path)
        } catch {
            self.error = String(describing: error)
        }
    }

    func openSharedDirInFinder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: store.sharedDataDir, isDirectory: true))
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.shared.setEnabled(enabled)
        } catch {
            self.error = "Launch at login failed: \(error)"
            LaunchAtLoginManager.shared.refresh()
        }
    }
}
