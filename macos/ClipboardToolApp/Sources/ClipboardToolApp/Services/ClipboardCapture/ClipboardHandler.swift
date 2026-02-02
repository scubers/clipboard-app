import AppKit
import Foundation

// MARK: - Clipboard Event

/// Represents a clipboard copy event with available data
struct ClipboardEvent {
    /// The pasteboard that contains the data
    let pasteboard: NSPasteboard

    /// The application that was active when copy happened (best effort)
    let sourceApp: String?

    /// The timestamp when this event was detected
    let timestamp: Date

    /// All available types on the pasteboard
    var availableTypes: [NSPasteboard.PasteboardType] {
        pasteboard.types ?? []
    }
}

// MARK: - Handler Result

/// Result returned by a clipboard handler
enum ClipboardHandlerResult {
    /// Handler processed this event successfully
    case handled

    /// Handler decided not to handle this event
    case ignored

    /// Handler tried but encountered an error
    case failed(Error)
}

// MARK: - Clipboard Handler Protocol

/// Protocol for clipboard content handlers
///
/// Design Principles:
/// 1. Single Responsibility: Each handler handles one specific type or category of content
/// 2. Strict Type Matching: Handlers only declare the types they can handle
/// 3. Self-Contained Decision: Handlers decide whether to store, OCR, or ignore
/// 4. No Side Effects on Pasteboard: Handlers should not modify the pasteboard itself
/// 5. Class-Based: Requires class conformance for identity checking
protocol ClipboardHandler: AnyObject {
    /// The pasteboard types this handler can process
    ///
    /// If any of these types are present in the clipboard event, this handler will be invoked.
    /// Only one handler per event will be called (first match wins).
    var supportedTypes: [NSPasteboard.PasteboardType] { get }

    /// Handle the clipboard event
    ///
    /// - Parameter event: The clipboard event containing pasteboard data and metadata
    /// - Returns: `ClipboardHandlerResult` indicating whether this event was handled
    func handle(_ event: ClipboardEvent) async -> ClipboardHandlerResult
}

// MARK: - Handler Registry

/// Registry for clipboard content handlers
///
/// Design Principles:
/// 1. Strict Type Matching: Each type has at most one registered handler
/// 2. First Match Wins: The first handler whose supported types match gets the event
/// 3. Unknown Types: Events with no matching handler are logged but not processed
/// 4. Thread-Safe: Registry operations are MainActor-protected
@MainActor
final class ClipboardHandlerRegistry {
    /// Registered handlers keyed by pasteboard type
    private var handlers: [NSPasteboard.PasteboardType: ClipboardHandler] = [:]

    /// Optional callback for logging unhandled clipboard events
    var onUnhandledEvent: ((ClipboardEvent) -> Void)?

    /// Register a handler for specific pasteboard types
    ///
    /// If a handler is already registered for any of the types, it will be replaced.
    ///
    /// - Parameter handler: The handler to register
    func register(_ handler: ClipboardHandler) {
        for type in handler.supportedTypes {
            handlers[type] = handler
        }
    }

    /// Unregister a handler
    ///
    /// Removes the handler from all types it was registered for.
    ///
    /// - Parameter handler: The handler to unregister
    func unregister(_ handler: ClipboardHandler) {
        for type in handler.supportedTypes {
            // Cast to AnyObject for identity comparison
            if (handlers[type] as AnyObject) === (handler as AnyObject) {
                handlers.removeValue(forKey: type)
            }
        }
    }

    /// Process a clipboard event
    ///
    /// Finds the appropriate handler based on available pasteboard types and invokes it.
    ///
    /// - Parameter event: The clipboard event to process
    /// - Returns: Whether the event was handled or ignored
    @discardableResult
    func process(_ event: ClipboardEvent) async -> Bool {
        // Check all available types in the event
        for type in event.availableTypes {
            // Find handler for this type
            if let handler = handlers[type] {
                let result = await handler.handle(event)

                switch result {
                case .handled:
                    return true

                case .ignored:
                    // Handler explicitly ignored this event, try other types
                    continue

                case .failed(let error):
                    // Handler failed, log and continue trying other types
                    print("[ClipboardHandler] Handler for \(type) failed: \(error)")
                    continue
                }
            }
        }

        // No handler matched - log unknown type if callback is provided
        onUnhandledEvent?(event)
        return false
    }

    /// Clear all registered handlers
    func removeAll() {
        handlers.removeAll()
    }
}

// MARK: - Common Pasteboard Types

extension NSPasteboard.PasteboardType {
    /// Common text types
    static let text = NSPasteboard.PasteboardType.string

    /// Common image types
    static let imageTypes: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.jpg"),
        NSPasteboard.PasteboardType("public.webp"),
        NSPasteboard.PasteboardType("org.webmproject.webp"),
    ]

    /// File URL type
    static let fileURL = NSPasteboard.PasteboardType("public.file-url")

    /// RTF type
    static let rtf = NSPasteboard.PasteboardType("public.rtf")
}
