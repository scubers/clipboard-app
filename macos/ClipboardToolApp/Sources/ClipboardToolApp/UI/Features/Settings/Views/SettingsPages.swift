import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case preview = "Preview"
    case storage = "Storage"
    case shortcuts = "Shortcuts"
    case capture = "Capture"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .preview: return "eye"
        case .storage: return "folder"
        case .shortcuts: return "keyboard"
        case .capture: return "tray.and.arrow.down"
        case .advanced: return "wrench.and.screwdriver"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Common app behavior and startup."
        case .appearance: return "Readability and visual tuning."
        case .preview: return "Text rendering options for preview pane."
        case .storage: return "Where the app stores shared data."
        case .shortcuts: return "Keyboard shortcuts and hotkeys."
        case .capture: return "Control what gets captured and retained."
        case .advanced: return "Maintenance and data tools."
        }
    }
}

// HotkeyCapture moved to Services/Hotkey/HotkeyCapture.swift
