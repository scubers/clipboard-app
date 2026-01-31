import AppKit
import ApplicationServices
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel?
    private var localKeyMonitor: Any?
    private var appDeactivateObserver: Any?

    private var previousApp: NSRunningApplication?
    private var previousAppPID: pid_t?

    private let hotkey = HotkeyManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar utility behavior
        NSApp.setActivationPolicy(.accessory)

        // Start clipboard monitoring even if the UI is never opened.
        SharedAppState.shared.startMonitoring()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipboardTool")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Clipboard", action: #selector(openClipboard), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        hotkey.onTrigger = { [weak self] in
            self?.toggleClipboardPanel(fromHotkey: true)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePasteSelection(_:)),
            name: .clipboardToolPasteSelection,
            object: nil
        )

        // Hide panel when app deactivates (clicking outside / switching apps)
        appDeactivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.panel?.orderOut(nil)
        }

        // Create window lazily
    }

    @objc private func openClipboard() {
        // When triggered from the status bar menu, showing a window immediately can be swallowed
        // by the menu run loop. Deferring to the next tick avoids the “need to click twice” issue.
        DispatchQueue.main.async { [weak self] in
            self?.showClipboardPanel(rememberPreviousApp: false)
        }
    }

    @objc private func toggleClipboardPanel(fromHotkey: Bool = false) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        showClipboardPanel(rememberPreviousApp: fromHotkey)
    }

    private func showClipboardPanel(rememberPreviousApp: Bool = false) {
        if rememberPreviousApp {
            previousApp = NSWorkspace.shared.frontmostApplication
            previousAppPID = previousApp?.processIdentifier
        }

        if panel == nil {
            let view = ContentView()
            let hosting = NSHostingController(rootView: view)

            let p = NSPanel(contentViewController: hosting)
            p.title = "ClipboardTool"
            // Slightly wider than tall feels more like a clipboard popover.
            p.setContentSize(NSSize(width: 640, height: 520))
            p.styleMask = [.titled, .closable, .resizable, .utilityWindow]
            p.isReleasedWhenClosed = false
            p.level = .floating
            p.collectionBehavior = [.moveToActiveSpace]
            p.hidesOnDeactivate = true

            // ESC to close
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak p] event in
                if event.keyCode == 53 {
                    p?.orderOut(nil)
                    return nil
                }
                return event
            }

            panel = p
        }

        guard let panel else { return }

        // Position near status item button if possible (popover-like).
        if let button = statusItem.button,
           let btnWindow = button.window,
           let screen = btnWindow.screen {
            let btnFrameInScreen = btnWindow.convertToScreen(button.frame)
            let vf = screen.visibleFrame

            var x = btnFrameInScreen.midX - panel.frame.width / 2
            var y = btnFrameInScreen.minY - panel.frame.height - 8

            // Clamp to visible screen.
            x = max(vf.minX + 8, min(x, vf.maxX - panel.frame.width - 8))
            y = max(vf.minY + 8, min(y, vf.maxY - panel.frame.height - 8))

            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        // NSPanel generally cannot become a main window; calling makeMain() can assert.
        panel.makeFirstResponder(panel.contentView)

        // Ask SwiftUI to focus the search field every time we open.
        NotificationCenter.default.post(name: .clipboardToolFocusSearch, object: nil)
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func handlePasteSelection(_ note: Notification) {
        // Hide panel first so we don't interfere with the target app's input.
        panel?.orderOut(nil)

        guard let text = note.userInfo?[ClipboardToolNotificationKeys.text] as? String else {
            return
        }

        // Ensure we have permission to post synthetic keystrokes.
        // If not granted, we can still copy to clipboard, but cannot reliably paste into other apps.
        guard ensureAccessibilityTrusted() else {
            showAccessibilityPermissionAlert()
            return
        }

        // Best-effort: re-activate previous app and paste.
        if let previousApp {
            previousApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        // Paste via synthetic Cmd+V. Some apps need a short delay after activation before accepting keystrokes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.sendPasteKeystroke()
            // Retry once more for robustness.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.sendPasteKeystroke()
            }
        }

        // Note: we rely on the system pasteboard already containing `text`.
        _ = text
    }

    private func sendPasteKeystroke() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // 'v'

        // Send Cmd+V (down/up). Most apps don't require separate Cmd key down events.
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        vUp?.flags = .maskCommand

        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }

    private func ensureAccessibilityTrusted() -> Bool {
        // Prompt user on first use.
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        return AXIsProcessTrustedWithOptions(opts)
    }

    private func showAccessibilityPermissionAlert() {
        let bid = Bundle.main.bundleIdentifier ?? "(unknown bundle id)"
        let bpath = Bundle.main.bundlePath

        let alert = NSAlert()
        alert.messageText = "ClipboardTool needs Accessibility permission"
        alert.informativeText = "To paste into other apps automatically (Cmd+V), enable this exact app in System Settings → Privacy & Security → Accessibility (and possibly Input Monitoring).\n\nBundle ID: \(bid)\nApp Path: \(bpath)\n\nThe text is already copied to your clipboard; you can paste manually with Cmd+V."
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
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        if let appDeactivateObserver {
            NotificationCenter.default.removeObserver(appDeactivateObserver)
        }
        NSApp.terminate(nil)
    }
}
