import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel?
    private var localKeyMonitor: Any?
    private var appDeactivateObserver: Any?

    private let hotkey = HotkeyManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar utility behavior
        NSApp.setActivationPolicy(.accessory)

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
            self?.toggleClipboardPanel()
        }

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
            self?.showClipboardPanel()
        }
    }

    @objc private func toggleClipboardPanel() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        showClipboardPanel()
    }

    private func showClipboardPanel() {
        if panel == nil {
            let view = ContentView()
            let hosting = NSHostingController(rootView: view)

            let p = NSPanel(contentViewController: hosting)
            p.title = "ClipboardTool"
            p.setContentSize(NSSize(width: 720, height: 520))
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

        // Position near status item button if possible
        if let button = statusItem.button {
            let btnFrameInScreen = button.window?.convertToScreen(button.frame) ?? .zero
            let x = max(20, btnFrameInScreen.midX - panel.frame.width / 2)
            let y = btnFrameInScreen.minY - panel.frame.height - 8
            panel.setFrameOrigin(NSPoint(x: x, y: max(20, y)))
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        // NSPanel generally cannot become a main window; calling makeMain() can assert.
        panel.makeFirstResponder(panel.contentView)
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
