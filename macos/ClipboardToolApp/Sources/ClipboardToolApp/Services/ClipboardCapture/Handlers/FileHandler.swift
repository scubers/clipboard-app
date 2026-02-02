import AppKit
import Foundation
import os.log

/// Handler for file URLs on clipboard
///
/// When users copy files in Finder, the clipboard contains file URLs.
/// This handler must be registered BEFORE TextHandler to prevent file names
/// from being incorrectly captured as text.
final class FileHandler: ClipboardHandler {
    private let logger = Logger(subsystem: "com.jaylen.clipboardtool", category: "FileHandler")

    /// File URL type - should be checked before text type
    var supportedTypes: [NSPasteboard.PasteboardType] {
        [.fileURL]
    }

    func handle(_ event: ClipboardEvent) async -> ClipboardHandlerResult {
        // Check for file URLs on pasteboard
        guard event.pasteboard.canReadObject(forClasses: [NSURL.self]),
              let urls = event.pasteboard.readObjects(forClasses: [NSURL.self], options: [:]) as? [NSURL],
              !urls.isEmpty else {
            return .ignored
        }

        // Extract file paths from URLs
        let filePaths = urls.compactMap { url in
            if let path = url.absoluteString {
                return path
            }
            return nil
        }
        guard !filePaths.isEmpty else {
            return .ignored
        }

        // Log file copy event for debugging
        logger.debug("File copy detected from \(event.sourceApp ?? "unknown app"): \(filePaths.count) file(s)")

        // For now, we ignore file copies.
        // Future enhancement: could store file metadata or handle file content.
        return .handled
    }
}
