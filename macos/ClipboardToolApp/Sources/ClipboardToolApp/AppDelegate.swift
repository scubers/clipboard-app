import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var windowController: NSWindowController?
    private var localKeyMonitor: Any?

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
            self?.openClipboard()
        }

        // Create window lazily
    }

    @objc private func openClipboard() {
        if windowController == nil {
            let view = ContentView()
            let hosting = NSHostingController(rootView: view)

            let window = NSWindow(contentViewController: hosting)
            window.title = "ClipboardTool"
            window.setContentSize(NSSize(width: 520, height: 640))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false

            windowController = NSWindowController(window: window)

            // ESC to close (tool-like behavior)
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window] event in
                if event.keyCode == 53 { // ESC
                    window?.performClose(nil)
                    return nil
                }
                return event
            }
        }

        // Bring app to front and ensure the window can receive keyboard input.
        NSApp.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            window.makeMain()
            window.orderFrontRegardless()
            // Make sure a responder exists (SwiftUI FocusState will then take effect).
            window.makeFirstResponder(window.contentView)
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        NSApp.terminate(nil)
    }
}
