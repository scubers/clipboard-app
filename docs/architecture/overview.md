# ClipboardTool — V1 Architecture

This document describes the V1 architecture in detail.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         macOS App (SwiftUI)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │  Menu Bar    │  │   Main Panel │  │     Settings Window   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘ │
│         │                 │                     │               │
│         └─────────────────┴─────────────────────┴───────────────┘ │
│                            │                                    │
│                    ┌───────▼────────┐                           │
│                    │  ViewModels    │                           │
│                    └───────┬────────┘                           │
└────────────────────────────┼────────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  CoreClient    │  (Swift wrapper)
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  CoreBridge    │  (C bridge)
                    └────────┬────────┘
                             │
┌────────────────────────────┼────────────────────────────────────┐
│                    Go Core Library (C ABI)                     │
│                    ┌────────▼────────┐                        │
│                    │   ct_* API      │                        │
│                    └────────┬────────┘                        │
│                             │                                 │
│  ┌──────────────┬──────────┼──────────┬──────────────┐      │
│  │    Items     │  Settings │   Search │  Maintenance │      │
│  └──────────────┴──────────┴──────────┴──────────────┘      │
│                             │                                 │
│                    ┌────────▼────────┐                        │
│                    │     SQLite     │                        │
│                    └─────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

## Component Overview

### macOS App (SwiftUI)

#### Menu Bar Component
- Persistent menu bar icon
- Quick actions (Open, Privacy Mode toggle, Quit)
- Status indicators (Privacy mode on/off)

#### Main Panel Component
- Floating NSPanel (popover-like behavior)
- Search field with debounced input
- Item list with preview
- Keyboard navigation (Up/Down/Enter/Esc)

#### Settings Component
- Multi-tab sidebar navigation
- Per-feature setting groups
- Data directory management
- Database maintenance tools

### Go Core (C ABI)

See [../spec/core-abi.md](../spec/core-abi.md) for the complete C ABI specification.

#### Item Management
- Add text/image items
- List/search items with pagination
- Pin/unpin items
- Delete (soft delete) items
- Clear all (with keep pinned option)

#### Settings Management
- Privacy mode toggle
- Retention max items
- Dedupe window size

#### Search Engine
- FTS5 full-text search (preferred)
- LIKE fallback (for compatibility)
- Include/deleted option

#### Maintenance
- Vacuum database
- Optimize (PRAGMA optimize)
- Integrity check
- Export/import by directory

## Data Flow

### Capture Flow

```
NSPasteboard Change Detected
         │
         ▼
PasteboardMonitor.tick()
         │
         ▼
Create ClipboardEvent
         │
         ▼
ClipboardHandlerRegistry.dispatch()
         │
         ├─► TextHandler → CoreClient.addText()
         │
         ├─► ImageHandler → CoreClient.addImage()
         │
         └─► UnknownTypeLoggerHandler → Log
```

### Search Flow

```
User types in search field
         │
         ▼
Debounce (200-300ms)
         │
         ▼
CoreClient.search()
         │
         ▼
Go Core (SQLite FTS5 or LIKE)
         │
         ▼
JSON result returned
         │
         ▼
ViewModel updates filteredItems
         │
         ▼
UI refreshes list
```

## Threading Model

### Main Thread
- All SwiftUI View rendering
- ViewModels (@Published properties)
- CoreClient calls (wrapper)

### Background Thread
- Go Core execution (C ABI calls)
- SQLite operations
- OCR processing (Vision framework)

### Async Handler Pattern
Handlers execute asynchronously and may run on background threads. When handlers need to update `@Published` properties or call `@MainActor` methods, updates must be wrapped in `Task { @MainActor in ... }`.

## Error Handling

### Error Model
All exported C functions return `int32_t` status code:
- `0` = OK
- non-zero = error

### Error Retrieval
Core keeps a thread-local last error message accessible via `ct_last_error_message()`.

### Swift Error Propagation
CoreClient wraps C errors into Swift `Error` types for proper async/await support.

## Configuration Persistence

### UserDefaults (Per-device, not synced)
- Window placement (`panelFrame`)
- Last active display ID
- Ephemeral UI state (selected item, list filter)
- Custom hotkey settings

### Shared Directory (Synced)
- Go/core owns: `<sharedDir>/config/settings.json`
- macOS app owns: `<sharedDir>/config/macos.json`

## Related Documentation
- [../spec/overview.md](../spec/overview.md) - Product overview and goals
- [../spec/core-abi.md](../spec/core-abi.md) - Complete C ABI specification
- [../spec/data-model.md](../spec/data-model.md) - Data model and SQLite schema
- [macos.md](macos.md) - macOS-specific architecture
