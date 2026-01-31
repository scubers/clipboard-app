import Foundation

// A very small shared container so SettingsView can talk to the same CoreClient
// as the main content window.
@MainActor
final class SharedAppState: ObservableObject {
    static let shared = SharedAppState()

    let core = CoreClient()

    private init() {
        // Best-effort open
        try? core.open(dataDir: ClipboardViewModel.defaultDataDir)
    }
}
