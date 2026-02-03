# ClipboardTool (macOS) — Spec Overview

## 0. One-liner
A macOS menu-bar utility that captures clipboard history, lets the user search/copy/paste previous items quickly, and persists data locally in a single directory for easy migration. Future versions will add multi-device sync.

## 1. Goals
- **Clipboard history**: capture **text** (required). (Images deferred to V1.1+.)
- **Fast retrieval**: searchable list UI + quick copy.
- **Deterministic local persistence**: all app data stored under one directory (configurable), so users can back up/move easily.
- **Privacy mode**: a toggle that prevents capturing new clipboard items (and optionally hides existing ones).

## 2. Non-goals
- No multi-device synchronization.
- No cloud accounts or login.
- No OCR, no content classification beyond simple type detection.

## 3. Target Platform
- macOS 14+ (Sonoma) baseline.
- UI: Swift/SwiftUI.
- Core logic: Go library (cross-platform), exposed via C ABI for Swift to call.

## 4. Architecture Overview

### 4.1 Components
- **macOS UI app (SwiftUI)**
  - Menu bar item
  - Main window / popover list
  - No default global hotkey (user-configurable later)
  - Clipboard polling/monitoring (NSPasteboard)

- **Core library (Go)**
  - Data model for clipboard items
  - Local storage engine (SQLite)
  - Search engine (substring + optional FTS tokenization)
  - Export/import helpers (directory-based)

### 4.2 Go ↔ Swift Bridge
- Build a Go shared library exposing a small C API.
- Swift calls into the C API using a bridging header.

Proposed ABI style:
- `ct_*` functions returning error codes + out pointers.
- Strings as UTF-8 `char*` with explicit free.

See [../architecture/overview.md](../architecture/overview.md) for detailed architecture.

## 5. Data Model

### 5.1 ClipboardItem
Fields:
- `id` (string, UUID)
- `createdAtMs` (int64)
- `type` (enum: text | image | file | html | rtf | unknown)
- `summary` (string; first N chars of text, or filename, etc.)
- `contentRef` (string; path or blob key)
- `sourceApp` (optional string; if available)
- `pinned` (bool)
- `deletedAtMs` (optional int64)

### 5.2 Storage Directory Layout
All persistent state lives under a single directory, default:
- `~/Library/Application Support/ClipboardTool/`

But user can choose a custom directory (for migration / sync later).

Layout:
- `data/clipboard.sqlite`
- `data/blobs/` (content blobs for images/files)
- `config/settings.json`
- `logs/` (optional)

Decision:
- Prefer **SQLite** for simplicity and query/search.

See [data-model.md](data-model.md) for detailed schema.

## 6. Clipboard Capture Behavior

### 6.1 Capture Loop
- Poll NSPasteboard changeCount every 300–800ms (tunable).
- On change:
  - If Privacy Mode ON → do nothing.
  - Extract supported types in priority order:
    - string (public.utf8-plain-text)
    - png/tiff
    - file URLs
  - Normalize and compute a hash to dedupe (e.g., SHA-256 of canonical bytes).
  - If identical to last saved item within X seconds → skip.
  - Persist item + blob (if needed).

### 6.2 Dedupe Rules
- Do not store two consecutive identical items.
- Optional: global dedupe window (e.g., last 50 items).

### 6.3 Retention
- Default keep last N items (e.g., 500).
- When exceeding N: delete oldest non-pinned items.

## 7. UI/UX

### 7.1 Menu Bar
- Menu items:
  - Open Clipboard
  - Privacy Mode (toggle)
  - Open Data Folder
  - Settings
  - Quit

### 7.2 Main Window
- Search box at top.
- List of items (most recent first).
  - Shows time, app (if known), summary.
- Actions:
  - Click/select: preview
  - Enter: copy selected item to clipboard
  - Cmd+C: copy selected item to clipboard
  - Cmd+P: pin/unpin
  - Delete: remove from history

Notes:
- Focuses on: **listen → persist → preview → select → copy**.
- Auto-paste (copy+paste) is deferred (likely requires accessibility permissions).

### 7.3 Settings
- Data directory (view + change)
- Retention count
- Poll interval
- Launch at login

## 8. Privacy Mode
Two behaviors:
- **Capture privacy** (V1): when ON, stop capturing new items.
- Optional future: "hide existing items" (V1.1).

UI indicates state clearly in menu bar.

## 9. Logging & Diagnostics
- Minimal structured logs under `logs/`.
- Add a "Copy diagnostics" button in Settings.

## 10. Security Considerations
- Local-only in V1.
- Ensure no clipboard content is logged.
- When storing files/images, store as blobs with randomized names.

## 11. Future (Sync v2)
- Add P2P or server sync.
- With C option chosen earlier: default sync ON but privacy mode disables sync/capture.

## Confirmed Decisions
- macOS minimum version: 14+
- V1 scope: text-only
- No default global hotkey (user-configurable later)
- Focuses on: listen → preview → select → copy (no auto-paste)

## Related Documentation
- [../architecture/overview.md](../architecture/overview.md) - Detailed architecture
- [core-abi.md](core-abi.md) - Core C ABI specification
- [data-model.md](data-model.md) - Data model and SQLite schema
