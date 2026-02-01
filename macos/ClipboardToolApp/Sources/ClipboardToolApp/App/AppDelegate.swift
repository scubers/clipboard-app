import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    private let store = AppStore.shared
    private lazy var panelCoordinator = PanelCoordinator(store: store)

    private var previousApp: NSRunningApplication?

    private let hotkey = HotkeyManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Start clipboard monitoring even if the UI is never opened.
        store.startMonitoring()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Pasty")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Clipboard", action: #selector(openClipboard), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        hotkey.onTrigger = { [weak self] in
            // rememberPreviousApp so paste goes back.
            self?.previousApp = NSWorkspace.shared.frontmostApplication
            self?.panelCoordinator.togglePanel(fromHotkey: true)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePasteSelection(_:)),
            name: .clipboardToolPasteSelection,
            object: nil
        )
    }

    @objc private func openClipboard() {
        DispatchQueue.main.async { [weak self] in
            self?.panelCoordinator.showPanel(rememberPreviousApp: false)
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func handlePasteSelection(_ note: Notification) {
        // PanelCoordinator already hides the panel on deactivate; also hide proactively.
        // (No direct panel reference here.)

        let kind = (note.userInfo?[ClipboardToolNotificationKeys.kind] as? String) ?? "text"
        let text = note.userInfo?[ClipboardToolNotificationKeys.text] as? String

        if kind == "text" && (text == nil) {
            return
        }

        guard ensureAccessibilityTrusted() else {
            showAccessibilityPermissionAlert()
            return
        }

        if let previousApp {
            previousApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        let delay: TimeInterval = (kind == "image") ? 0.28 : 0.10
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.sendPasteKeystroke()
        }

        _ = text
    }

    private func sendPasteKeystroke() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // 'v'

        let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        vUp?.flags = .maskCommand

        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }

    private func ensureAccessibilityTrusted() -> Bool {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        return AXIsProcessTrustedWithOptions(opts)
    }

    private func showAccessibilityPermissionAlert() {
        let bid = Bundle.main.bundleIdentifier ?? "(unknown bundle id)"
        let bpath = Bundle.main.bundlePath

        let alert = NSAlert()
        alert.messageText = "Pasty needs Accessibility permission"
        alert.informativeText = "To paste into other apps automatically (Cmd+V), enable this exact app in System Settings → Privacy & Security → Accessibility (and possibly Input Monitoring).\n\nBundle ID: \(bid)\nApp Path: \(bpath)\n\nThe content is already copied to your clipboard; you can paste manually with Cmd+V."
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "OK")

        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
