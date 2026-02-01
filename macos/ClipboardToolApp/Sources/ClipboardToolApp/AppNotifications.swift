import Foundation

extension Notification.Name {
    static let clipboardToolFocusSearch = Notification.Name("ClipboardTool.focusSearch")
    static let clipboardToolItemsChanged = Notification.Name("ClipboardTool.itemsChanged")
    static let clipboardToolStorageChanged = Notification.Name("ClipboardTool.storageChanged")
    static let clipboardToolPasteSelection = Notification.Name("ClipboardTool.pasteSelection")
}

enum ClipboardToolNotificationKeys {
    static let text = "text"
    static let kind = "kind" // "text" | "image"
}
