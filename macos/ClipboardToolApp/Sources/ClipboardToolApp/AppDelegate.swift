import AppKit
import ApplicationServices
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel?
    private var localKeyMonitor: Any?
    private var appDeactivateObserver: Any?
    private var panelMoveObserver: Any?
    private var panelResizeObserver: Any?

    private var previousApp: NSRunningApplication?
    private var previousAppPID: pid_t?

    private let hotkey = HotkeyManager.shared

    private enum Keys {
        static let panelFrame = "ClipboardTool.panelFrame"
        static let lastPanelScreenID = "ClipboardTool.lastPanelScreenID"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar utility behavior
        NSApp.setActivationPolicy(.accessory)

        // Scroll indicator thickness/auto-hide mostly follow system settings.

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
            // Popover-like, minimal chrome.
            p.title = ""
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.isMovableByWindowBackground = true
            p.isOpaque = false
            p.backgroundColor = .clear

            // Slightly wider than tall, Raycast-like.
            p.setContentSize(NSSize(width: 760, height: 520))
            p.styleMask = [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView]
            p.isReleasedWhenClosed = false
            p.level = .floating
            p.collectionBehavior = [.moveToActiveSpace]
            p.hidesOnDeactivate = true

            // Traffic lights behavior is configurable.
            let hide = UserDefaults.standard.object(forKey: "ClipboardTool.hideTrafficLights") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "ClipboardTool.hideTrafficLights")
            p.standardWindowButton(.closeButton)?.isHidden = hide
            p.standardWindowButton(.miniaturizeButton)?.isHidden = hide
            p.standardWindowButton(.zoomButton)?.isHidden = hide

            // Persist window frame.
            observePanelFrame(p)

            // Apply last saved frame (or default placement).
            applyInitialPanelPlacement(p)

            // ESC to close; Return to paste (default behavior).
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak p] event in
                // Only handle keys when our panel is visible.
                if let p, p.isVisible {
                    // ESC
                    if event.keyCode == 53 {
                        p.orderOut(nil)
                        return nil
                    }
                    // Up / Down selection
                    if event.keyCode == 126 { // up
                        NotificationCenter.default.post(name: .clipboardToolSelectPrev, object: nil)
                        return nil
                    }
                    if event.keyCode == 125 { // down
                        NotificationCenter.default.post(name: .clipboardToolSelectNext, object: nil)
                        return nil
                    }

                    // Return / Enter
                    if event.keyCode == 36 || event.keyCode == 76 {
                        NotificationCenter.default.post(name: .clipboardToolPasteAction, object: nil)
                        return nil
                    }
                }
                _ = self
                return event
            }

            panel = p
        }

        guard let panel else { return }

        // Placement:
        // - First open: applyInitialPanelPlacement(p)
        // - Subsequent opens: keep last position, *unless* the current activation is on a different
        //   screen than the last activation. In that case, show at default position on the current screen.
        maybeRelocatePanelForCurrentMouseScreen(panel)

        // Apply current traffic-light preference each time.
        let hide = UserDefaults.standard.object(forKey: "ClipboardTool.hideTrafficLights") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "ClipboardTool.hideTrafficLights")
        panel.standardWindowButton(.closeButton)?.isHidden = hide
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = hide
        panel.standardWindowButton(.zoomButton)?.isHidden = hide

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

        let kind = (note.userInfo?[ClipboardToolNotificationKeys.kind] as? String) ?? "text"
        let text = note.userInfo?[ClipboardToolNotificationKeys.text] as? String

        // For image paste we may not have a text payload; that's ok.
        if kind == "text" && (text == nil) {
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
        // Empirically, image paste can require more time for the pasteboard to settle (e.g. WeChat).
        let delay: TimeInterval = (kind == "image") ? 0.28 : 0.10
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.sendPasteKeystroke()
        }

        // Note: we rely on the system pasteboard already containing the selected content.
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

    // Traffic lights are applied inline using UserDefaults (avoid MainActor crossing in AppDelegate).

    private func applyInitialPanelPlacement(_ panel: NSPanel) {
        if let s = UserDefaults.standard.string(forKey: Keys.panelFrame) {
            let rect = NSRectFromString(s)
            if rect.width > 0, rect.height > 0 {
                panel.setFrame(rect, display: false)
                return
            }
        }

        // First open: current screen (by mouse position), centered slightly top.
        placePanelAtDefaultPosition(on: mouseScreen() ?? NSScreen.main, panel: panel)
    }

    private func screenID(_ screen: NSScreen) -> UInt32? {
        // NSScreenNumber is a CGDirectDisplayID.
        let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return n?.uint32Value
    }

    private func mouseScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
    }

    private func placePanelAtDefaultPosition(on screen: NSScreen?, panel: NSPanel) {
        guard let screen else { return }
        let vf = screen.visibleFrame
        let size = panel.frame.size

        let x = vf.midX - size.width / 2
        // "Slightly top": shift up by ~12% of visible height.
        let y = vf.midY + vf.height * 0.12 - size.height / 2

        panel.setFrameOrigin(NSPoint(
            x: max(vf.minX + 8, min(x, vf.maxX - size.width - 8)),
            y: max(vf.minY + 8, min(y, vf.maxY - size.height - 8))
        ))
    }

    private func maybeRelocatePanelForCurrentMouseScreen(_ panel: NSPanel) {
        guard let curScreen = mouseScreen() else { return }
        guard let curID = screenID(curScreen) else { return }

        let lastID = UInt32(UserDefaults.standard.integer(forKey: Keys.lastPanelScreenID))

        // Detect whether the current saved frame is actually on the current mouse screen.
        // (Users can have multiple displays; frames are in a global coordinate space.)
        let curVF = curScreen.visibleFrame
        let frame = panel.frame
        let frameCenter = NSPoint(x: frame.midX, y: frame.midY)
        let frameIsOnCurScreen = curVF.contains(frameCenter)

        // Rule:
        // - Always show on the mouse screen.
        // - If switching screens between activations, use default placement.
        // - If the stored frame is not on the mouse screen (e.g. first run after update / stale prefs),
        //   also reset to default placement on the mouse screen.
        if (lastID != 0 && lastID != curID) || !frameIsOnCurScreen {
            placePanelAtDefaultPosition(on: curScreen, panel: panel)
            savePanelFrame(panel)
        }

        UserDefaults.standard.set(Int(curID), forKey: Keys.lastPanelScreenID)
    }

    private func observePanelFrame(_ panel: NSPanel) {
        panelMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.savePanelFrame(panel)
        }

        panelResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.savePanelFrame(panel)
        }
    }

    private func savePanelFrame(_ panel: NSPanel) {
        let rect = panel.frame
        UserDefaults.standard.set(NSStringFromRect(rect), forKey: Keys.panelFrame)
    }

    @objc private func quit() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        if let appDeactivateObserver {
            NotificationCenter.default.removeObserver(appDeactivateObserver)
        }
        if let panelMoveObserver {
            NotificationCenter.default.removeObserver(panelMoveObserver)
        }
        if let panelResizeObserver {
            NotificationCenter.default.removeObserver(panelResizeObserver)
        }
        NSApp.terminate(nil)
    }
}
