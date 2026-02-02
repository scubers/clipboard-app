# Clipboard Handler Architecture

> Status: implemented
> Version: 1.0
> Date: 2026-02-03

## Overview

The clipboard handler architecture provides a flexible, extensible framework for processing clipboard content. It follows a **handler registration pattern** where:

1. **PasteboardMonitor** detects clipboard changes
2. **ClipboardHandlerRegistry** manages registered handlers
3. Individual **ClipboardHandler** implementations process specific content types

This design enables new clipboard types to be added without modifying core monitoring logic.

---

## Motivation

### Problems with Previous Design

The original `PasteboardMonitor` had direct callbacks for text and image:
- Type handling was hardcoded in the monitor
- Unknown types were incorrectly forced to string fallback
- Adding new types required modifying the monitor class
- Hard to test individual type handlers
- Violated Single Responsibility Principle

### Goals

1. **Separation of Concerns**: Monitoring vs. content processing
2. **Strict Type Matching**: No fallback to incorrect types
3. **Extensibility**: Add new types without core changes
4. **Testability**: Independent testing of handlers
5. **Clear Failure Handling**: Unknown types logged, not silently ignored

---

## Core Components

### ClipboardEvent

Represents a clipboard copy event with all available data:

```swift
struct ClipboardEvent {
    let pasteboard: NSPasteboard
    let sourceApp: String?
    let timestamp: Date
    var availableTypes: [NSPasteboard.PasteboardType]
}
```

### ClipboardHandler Protocol

```swift
protocol ClipboardHandler: AnyObject {
    /// Types this handler can process
    var supportedTypes: [NSPasteboard.PasteboardType] { get }

    /// Handle the clipboard event
    func handle(_ event: ClipboardEvent) async -> ClipboardHandlerResult
}
```

### ClipboardHandlerResult

```swift
enum ClipboardHandlerResult {
    case handled      // Handler processed successfully
    case ignored      // Handler chose not to process
    case failed(Error) // Handler encountered error
}
```

### ClipboardHandlerRegistry

Manages handler registration and event dispatch:

```swift
@MainActor
final class ClipboardHandlerRegistry {
    func register(_ handler: ClipboardHandler)
    func unregister(_ handler: ClipboardHandler)
    func process(_ event: ClipboardEvent) async -> Bool
    var onUnhandledEvent: ((ClipboardEvent) -> Void)?
}
```

---

## Design Principles

### 1. Single Responsibility
- **PasteboardMonitor**: Only detects clipboard changes
- **HandlerRegistry**: Routes events to appropriate handlers
- **Concrete Handlers**: Handle specific content types

### 2. Strict Type Matching
- Each type has at most one registered handler
- No fallback to incorrect types
- Unknown types are logged via `onUnhandledEvent`

### 3. Handler Autonomy
- Handlers decide whether to store, OCR, or ignore
- Handlers define their own supported types
- Handlers can be async (for operations like OCR)

### 4. First Match Wins
When multiple types are available on clipboard:
- Check each type in `availableTypes`
- First registered handler for a matching type is called
- Once a handler returns `.handled`, processing stops

### 5. Graceful Degradation
- Handler failures are logged but don't crash monitoring
- One handler's error doesn't prevent other types from being tried
- Unknown types are logged for debugging without affecting user experience

---

## Handler Registration

```swift
// In AppStore.startMonitoring()
let textHandler = TextHandler(core: core) { text, sourceApp in
    self.incrementItemsVersion()
}
monitor.handlerRegistry.register(textHandler)

let imageHandler = ImageHandler(core: core) { data, mime, sourceApp in
    self.incrementItemsVersion()
}
monitor.handlerRegistry.register(imageHandler)
```

### Unregistering (Future Use)

```swift
monitor.handlerRegistry.unregister(textHandler)
```

---

## Implementation Examples

### TextHandler

```swift
final class TextHandler: ClipboardHandler {
    private let core: CoreClient
    private let onAdd: ((String, String?) -> Void)?

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
```

### ImageHandler

```swift
final class ImageHandler: ClipboardHandler {
    private let core: CoreClient
    private let candidates: [(NSPasteboard.PasteboardType, String)] = [
        (.png, "image/png"),
        (.tiff, "image/tiff"),
        (NSPasteboard.PasteboardType("public.jpeg"), "image/jpeg"),
        // ... more types
    ]

    var supportedTypes: [NSPasteboard.PasteboardType] {
        candidates.map { $0.0 }
    }

    func handle(_ event: ClipboardEvent) async -> ClipboardHandlerResult {
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
```

### UnknownTypeLoggerHandler

```swift
final class UnknownTypeLoggerHandler: ClipboardHandler {
    private let logger = Logger(subsystem: "...", category: "ClipboardHandler")

    var supportedTypes: [NSPasteboard.PasteboardType] {
        [] // Empty - used via registry callback only
    }

    func handle(_ event: ClipboardEvent) async -> ClipboardHandlerResult {
        return .ignored
    }

    func logUnhandled(_ event: ClipboardEvent) {
        let types = event.availableTypes.map { $0.rawValue }.joined(separator: ", ")
        logger.info("Unhandled clipboard event: [\(types)]")
    }
}
```

---

## Event Flow

```
Clipboard Change Detected
        ↓
PasteboardMonitor.tick()
        ↓
Create ClipboardEvent(pasteboard, sourceApp, timestamp)
        ↓
ClipboardHandlerRegistry.process(event)
        ↓
For each type in event.availableTypes:
    ├─ Find handler for this type
    ├─ If found: await handler.handle(event)
    │   ├─ .handled → Stop processing
    │   ├─ .ignored → Try next type
    │   └─ .failed → Log error, try next type
    └─ If no handler matches:
        └─ Call onUnhandledEvent callback
```

---

## Adding New Handlers

### Example: RTF Handler

```swift
final class RTFHandler: ClipboardHandler {
    private let core: CoreClient

    var supportedTypes: [NSPasteboard.PasteboardType] {
        [.rtf]
    }

    func handle(_ event: ClipboardEvent) async -> ClipboardHandlerResult {
        guard let data = event.pasteboard.data(forType: .rtf), !data.isEmpty else {
            return .ignored
        }
        // Convert RTF to HTML or store as RTF
        // Implementation depends on core API
        return .handled
    }
}
```

Register in `AppStore.startMonitoring()`:
```swift
let rtfHandler = RTFHandler(core: core)
monitor.handlerRegistry.register(rtfHandler)
```

---

## Future Extensions

### OCR Handler

A future handler could:
1. Check for image content
2. Extract text via OCR
3. Store both image and OCR text as linked items
4. Enable searching for image content

### File Handler

A future handler could:
1. Detect file URLs on clipboard
2. Copy files to blob storage
3. Store metadata (filename, size, type)

### URL Handler

A future handler could:
1. Detect URLs on clipboard
2. Store as special "URL" item type
3. Allow quick opening of stored URLs

---

## Directory Structure

```
Services/ClipboardCapture/
├── PasteboardMonitor.swift           # Detection only
├── ClipboardHandler.swift            # Protocol + Registry
└── Handlers/
    ├── TextHandler.swift              # Plain text
    ├── ImageHandler.swift             # Images (PNG, TIFF, JPEG, WebP)
    ├── UnknownTypeLoggerHandler.swift  # Logging
    └── [Future handlers...]
```

---

## Testing Strategy

### Unit Tests

Each handler can be tested independently:

```swift
func testTextHandler() async {
    let mockCore = MockCoreClient()
    let handler = TextHandler(core: mockCore)

    let pasteboard = NSPasteboard.general
    pasteboard.setString("test", forType: .string)

    let event = ClipboardEvent(pasteboard: pasteboard, sourceApp: "TestApp", timestamp: Date())
    let result = await handler.handle(event)

    XCTAssertEqual(result, .handled)
    XCTAssertTrue(mockCore.addTextCalled)
}
```

### Integration Tests

```swift
func testHandlerRegistry() async {
    let registry = ClipboardHandlerRegistry()
    let textHandler = TextHandler(core: mockCore)

    registry.register(textHandler)

    let event = ClipboardEvent(...)
    let handled = await registry.process(event)

    XCTAssertTrue(handled)
}
```

---

## Performance Considerations

1. **Async Handlers**: Handlers can be async for expensive operations
2. **MainActor**: Registry and monitor are MainActor-protected
3. **No Blocking**: Clipboard detection doesn't wait for handler completion
4. **Error Isolation**: Handler errors don't affect monitoring loop

---

## Thread Safety

### Problem
Handlers execute asynchronously and may run on background threads. When handlers need to update `@Published` properties or call `@MainActor` methods, we must ensure updates happen on the main thread.

### Warning Message
```
Publishing changes from background threads is not allowed; make sure to publish values from main thread (via operators like receive(on:)) on model updates.
```

### Solution
Wrap `@MainActor` updates in `Task { @MainActor in ... }`:

```swift
// ❌ Wrong - callback runs on background thread
let textHandler = TextHandler(core: core) { [weak self] text, sourceApp in
    self.incrementItemsVersion()  // May crash if not on main thread!
}

// ✅ Correct - ensures main thread execution
let textHandler = TextHandler(core: core) { [weak self] text, sourceApp in
    Task { @MainActor in
        self.incrementItemsVersion()  // Guaranteed to run on main thread
    }
}
```

### Rules
1. **Handler callbacks**: Always wrap `@MainActor` calls in `Task { @MainActor in ... }`
2. **Published property updates**: Must happen on main thread
3. **Async handler methods**: May run on any thread, don't assume main thread
4. **Registry operations**: `ClipboardHandlerRegistry` is `@MainActor`-protected, safe to call from anywhere

---

## Logging

Unknown clipboard types are logged using `os.Logger`:
- Subsystem: `com.jaylen.clipboardtool`
- Category: `ClipboardHandler`

Log format:
```
Unhandled clipboard event from {app}: [type1, type2, type3]
```

This helps identify:
1. What types users are copying
2. Which types need handler support
3. Debugging unexpected behavior
