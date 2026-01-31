import SwiftUI

@main
struct ClipboardToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default window at launch; menu bar controls it.
        Settings {
            SettingsView()
        }
    }
}
