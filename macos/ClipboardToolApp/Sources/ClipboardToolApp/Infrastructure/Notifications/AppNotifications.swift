import Foundation

// Note: App-specific notifications have been removed in favor of data-driven architecture.
// Components now communicate via:
// - @Published properties in AppStore and ViewModels
// - Direct method calls (e.g., PanelCoordinator → ViewModel)
// - Callbacks/closures for cross-component events (e.g., AppStore.onPasteComplete)

// If new notifications are needed in the future, add them here with clear documentation
// of why a notification is the appropriate pattern over data-binding or method calls.

// System-level notifications (NSApplication, NSWindow, etc.) are used directly from AppKit
// and do not need to be redefined here.
