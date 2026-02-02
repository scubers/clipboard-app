import AppKit
import Foundation
import os.log

/// Handler that logs unhandled clipboard types for debugging
///
/// This handler should be used as a fallback to record what types are being
/// encountered but not processed by any other handler.
final class UnknownTypeLoggerHandler: ClipboardHandler {
    private let logger = Logger(subsystem: "com.jaylen.clipboardtool", category: "ClipboardHandler")

    /// We don't register specific types; this handler is called via
    /// the registry's `onUnhandledEvent` callback instead.
    var supportedTypes: [NSPasteboard.PasteboardType] {
        []
    }

    func handle(_ event: ClipboardEvent) async -> ClipboardHandlerResult {
        // This handler should never be called directly.
        // Unknown types are handled by the registry's onUnhandledEvent callback.
        return .ignored
    }

    /// Log an unhandled clipboard event
    ///
    /// This method should be called from the registry's onUnhandledEvent callback.
    func logUnhandled(_ event: ClipboardEvent) {
        let types = event.availableTypes.map { $0.rawValue }.joined(separator: ", ")
        logger.info("Unhandled clipboard event from \(event.sourceApp ?? "unknown app"): [\(types)]")
    }
}
