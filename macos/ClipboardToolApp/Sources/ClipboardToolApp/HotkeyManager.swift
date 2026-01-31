import AppKit
import Carbon
import Foundation

/// Global hotkey registration using Carbon RegisterEventHotKey.
/// This works for menu-bar utilities where we want to show the window from anywhere.
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Keys.enabled) }
    }

    /// Stored as an identifier string, e.g. "cmd+shift+v".
    @Published var hotkeyId: String {
        didSet { UserDefaults.standard.set(hotkeyId, forKey: Keys.hotkeyId) }
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// Callback invoked when hotkey fires.
    var onTrigger: (() -> Void)?

    private enum Keys {
        static let enabled = "ClipboardTool.hotkey.enabled"
        static let hotkeyId = "ClipboardTool.hotkey.id"
    }

    private init() {
        if UserDefaults.standard.object(forKey: Keys.enabled) != nil {
            enabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        } else {
            enabled = false
        }
        hotkeyId = UserDefaults.standard.string(forKey: Keys.hotkeyId) ?? "cmd+shift+v"

        installHandlerIfNeeded()
        refreshRegistration()
    }

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func availableHotkeys() -> [String] {
        // V1: keep it simple with presets. Later we can add a recorder control.
        [
            "cmd+shift+v",
            "cmd+shift+space",
            "opt+space",
            "ctrl+opt+v",
            "ctrl+opt+space"
        ]
    }

    func setHotkey(id: String) {
        hotkeyId = id
        refreshRegistration()
    }

    func refreshRegistration() {
        unregister()
        guard enabled else { return }
        guard let parsed = Self.parseHotkey(id: hotkeyId) else { return }
        register(keyCode: parsed.keyCode, modifiers: parsed.modifiers)
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // C callback -> call back into the singleton on main actor.
        let handler: EventHandlerUPP = { _, eventRef, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr {
                DispatchQueue.main.async {
                    HotkeyManager.shared.onTrigger?()
                }
            }
            return noErr
        }

        var ref: EventHandlerRef?
        let status = InstallEventHandler(GetApplicationEventTarget(), handler, 1, [eventSpec], nil, &ref)
        if status == noErr {
            eventHandlerRef = ref
        }
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4157) /*'CLAW'*/, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
        }
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    // MARK: - Parsing

    /// Returns Carbon keyCode + modifiers.
    static func parseHotkey(id: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        // Accept formats like: cmd+shift+v, ctrl+opt+space
        let parts = id.lowercased().split(separator: "+").map(String.init)
        guard parts.count >= 2 else { return nil }

        var modifiers: UInt32 = 0
        var key: String?

        for p in parts {
            switch p {
            case "cmd", "command": modifiers |= UInt32(cmdKey)
            case "shift": modifiers |= UInt32(shiftKey)
            case "opt", "option", "alt": modifiers |= UInt32(optionKey)
            case "ctrl", "control": modifiers |= UInt32(controlKey)
            default:
                key = p
            }
        }
        guard let key else { return nil }

        let keyCode: UInt32?
        switch key {
        case "v": keyCode = UInt32(kVK_ANSI_V)
        case "space": keyCode = UInt32(kVK_Space)
        default: keyCode = nil
        }
        guard let keyCode else { return nil }

        // Carbon hotkey modifiers use these bitflags (cmdKey/optionKey/shiftKey/controlKey).
        return (keyCode, modifiers)
    }
}
