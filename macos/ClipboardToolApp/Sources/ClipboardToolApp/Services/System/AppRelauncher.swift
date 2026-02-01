import AppKit
import Foundation

enum AppRelauncher {
    /// Best-effort restart: spawn a new instance of this app, then terminate.
    /// Works for installed .app bundles; for Xcode/debug runs, behavior may vary.
    static func restart() {
        let appPath = Bundle.main.bundlePath

        // Prefer /usr/bin/open so we can launch the .app bundle.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-n", appPath]

        do {
            try p.run()
        } catch {
            // Fallback: try NSWorkspace
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath), configuration: NSWorkspace.OpenConfiguration()) { _, _ in
                // no-op
            }
        }

        // Quit current instance.
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }
}
