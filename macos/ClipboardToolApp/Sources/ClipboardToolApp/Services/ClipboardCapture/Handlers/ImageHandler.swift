import AppKit
import Foundation

/// Handler for image clipboard content
final class ImageHandler: ClipboardHandler {
    private let core: CoreClient
    private let onAdd: ((Data, String, String?) -> Void)?

    /// Candidate image types to check, in order of preference
    /// Format: (pasteboardType, mimeType)
    private let candidates: [(NSPasteboard.PasteboardType, String)] = [
        (.png, "image/png"),
        (.tiff, "image/tiff"),
        (NSPasteboard.PasteboardType("public.jpeg"), "image/jpeg"),
        (NSPasteboard.PasteboardType("public.jpg"), "image/jpeg"),
        (NSPasteboard.PasteboardType("public.webp"), "image/webp"),
        (NSPasteboard.PasteboardType("org.webmproject.webp"), "image/webp"),
    ]

    init(core: CoreClient, onAdd: ((Data, String, String?) -> Void)? = nil) {
        self.core = core
        self.onAdd = onAdd
    }

    var supportedTypes: [NSPasteboard.PasteboardType] {
        candidates.map { $0.0 }
    }

    func handle(_ event: ClipboardEvent) async -> ClipboardHandlerResult {
        // Try each image type in order
        for (pasteboardType, mimeType) in candidates {
            guard let data = event.pasteboard.data(forType: pasteboardType), !data.isEmpty else {
                continue
            }

            do {
                try core.addImage(mime: mimeType, data: data, sourceApp: event.sourceApp)
                onAdd?(data, mimeType, event.sourceApp)
                return .handled
            } catch {
                return .failed(error)
            }
        }

        return .ignored
    }
}
