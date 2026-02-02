import AppKit
import Foundation

/// Handler for plain text clipboard content
final class TextHandler: ClipboardHandler {
    private let core: CoreClient
    private let onAdd: ((String, String?) -> Void)?

    init(core: CoreClient, onAdd: ((String, String?) -> Void)? = nil) {
        self.core = core
        self.onAdd = onAdd
    }

    var supportedTypes: [NSPasteboard.PasteboardType] {
        [.string]
    }

    func handle(_ event: ClipboardEvent) async -> ClipboardHandlerResult {
        guard let text = event.pasteboard.string(forType: .string), !text.isEmpty else {
            return .ignored
        }

        do {
            try core.addText(text, sourceApp: event.sourceApp)
            onAdd?(text, event.sourceApp)
            return .handled
        } catch {
            return .failed(error)
        }
    }
}
