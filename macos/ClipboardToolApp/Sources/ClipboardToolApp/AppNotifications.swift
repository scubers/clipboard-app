import Foundation

extension Notification.Name {
    static let clipboardToolFocusSearch = Notification.Name("ClipboardTool.focusSearch")
    static let clipboardToolItemsChanged = Notification.Name("ClipboardTool.itemsChanged")
    static let clipboardToolStorageChanged = Notification.Name("ClipboardTool.storageChanged")
    static let clipboardToolPasteSelection = Notification.Name("ClipboardTool.pasteSelection")
    static let clipboardToolPasteAction = Notification.Name("ClipboardTool.pasteAction")
    static let clipboardToolSelectPrev = Notification.Name("ClipboardTool.selectPrev")
    static let clipboardToolSelectNext = Notification.Name("ClipboardTool.selectNext")
}

enum ClipboardToolNotificationKeys {
    static let text = "text"
    static let kind = "kind" // "text" | "image"
}
