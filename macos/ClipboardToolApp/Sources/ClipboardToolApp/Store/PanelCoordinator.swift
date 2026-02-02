import AppKit
import ApplicationServices
import SwiftUI

/// Owns the main floating panel (popover-like window) and its windowing behavior.
///
/// Rules:
/// - Panel shows on the current mouse screen (see placement logic).
/// - Panel hides on app deactivate.
/// - Panel is the only place that knows about NSPanel creation, key monitors, and placement.
@MainActor
final class PanelCoordinator {
    private let store: AppStore
    private weak var viewModel: MainPanelViewModel?

    private var panel: NSPanel?
    private var localKeyMonitor: Any?
    private var appDeactivateObserver: Any?
    private var panelMoveObserver: Any?
    private var panelResizeObserver: Any?

    private var previousApp: NSRunningApplication?
    private var previousAppPID: pid_t?

    private enum Keys {
        static let panelFrame = "ClipboardTool.panelFrame"
        static let lastPanelScreenID = "ClipboardTool.lastPanelScreenID"
    }

    init(store: AppStore, viewModel: MainPanelViewModel?) {
        self.store = store
        self.viewModel = viewModel

        // Hide panel when app deactivates (clicking outside / switching apps)
        appDeactivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.panel?.orderOut(nil)
            }
        }
    }

    deinit {
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
    }

    func togglePanel(fromHotkey: Bool = false) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        showPanel(rememberPreviousApp: fromHotkey)
    }

    func showPanel(rememberPreviousApp: Bool = false) {
        if rememberPreviousApp {
            previousApp = NSWorkspace.shared.frontmostApplication
            previousAppPID = previousApp?.processIdentifier
            _ = previousAppPID
        }

        if panel == nil {
            guard let viewModel = viewModel else { return }
            let view = ContentView(vm: viewModel)
            let hosting = NSHostingController(rootView: view)

            let p = NSPanel(contentViewController: hosting)
            p.title = ""
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.isMovableByWindowBackground = true
            p.isOpaque = false
            p.backgroundColor = .clear

            p.setContentSize(NSSize(width: 760, height: 520))
            p.styleMask = [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView]
            p.isReleasedWhenClosed = false
            p.level = .floating
            p.collectionBehavior = [.moveToActiveSpace]
            p.hidesOnDeactivate = true

            applyTrafficLights(p)

            observePanelFrame(p)
            applyInitialPanelPlacement(p)

            // ESC to close; Return to paste (default behavior).
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak p] event in
                guard let self, let p, p.isVisible else { return event }

                switch event.keyCode {
                case 53: // ESC
                    p.orderOut(nil)
                    return nil
                case 126: // Up arrow
                    self.viewModel?.selectPrev()
                    return nil
                case 125: // Down arrow
                    self.viewModel?.selectNext()
                    return nil
                case 36, 76: // Enter / Return
                    self.viewModel?.pasteSelectedToPreviousApp()
                    return nil
                default:
                    return event
                }
            }

            panel = p
        }

        guard let panel else { return }

        // Ensure correct placement for current mouse screen.
        maybeRelocatePanelForCurrentMouseScreen(panel)

        // Apply current traffic-light preference each time.
        applyTrafficLights(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        // NOTE: Don't call makeFirstResponder here - let SwiftUI's @FocusState handle it.

        // Reset focus to search and select first item after window is fully shown.
        // Small delay ensures SwiftUI has processed the window becoming key.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.viewModel?.resetFocusToSearch()
        }
    }

    private func applyTrafficLights(_ panel: NSPanel) {
        let hide = store.hideTrafficLights
        panel.standardWindowButton(.closeButton)?.isHidden = hide
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = hide
        panel.standardWindowButton(.zoomButton)?.isHidden = hide
    }

    // MARK: - Placement

    private func applyInitialPanelPlacement(_ panel: NSPanel) {
        if let s = UserDefaults.standard.string(forKey: Keys.panelFrame) {
            let rect = NSRectFromString(s)
            if rect.width > 0, rect.height > 0 {
                panel.setFrame(rect, display: false)
                return
            }
        }
        placePanelAtDefaultPosition(on: mouseScreen() ?? NSScreen.main, panel: panel)
    }

    private func screenID(_ screen: NSScreen) -> UInt32? {
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

        let curVF = curScreen.visibleFrame
        let frame = panel.frame
        let frameCenter = NSPoint(x: frame.midX, y: frame.midY)
        let frameIsOnCurScreen = curVF.contains(frameCenter)

        if (lastID != 0 && lastID != curID) || !frameIsOnCurScreen {
            placePanelAtDefaultPosition(on: curScreen, panel: panel)
            savePanelFrame(panel)
        }

        UserDefaults.standard.set(Int(curID), forKey: Keys.lastPanelScreenID)
    }

    // MARK: - Frame persistence

    private func observePanelFrame(_ panel: NSPanel) {
        panelMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.savePanelFrame(panel)
            }
        }

        panelResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.savePanelFrame(panel)
            }
        }
    }

    private func savePanelFrame(_ panel: NSPanel) {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: Keys.panelFrame)
    }
}
