# ClipboardTool — Design Decisions

This document records architectural and design decisions made during development.

## Core Technology

### Core Language: Go (for cross-platform core)
- Chosen for ease of cross-platform compilation
- C ABI allows integration with Swift on macOS and future platforms

### Storage: SQLite (single directory)
- All app data lives under one directory for easy migration
- Supports FTS5 for efficient full-text search

## V1 Scope Decisions

### No Multi-Device Sync in V1
- V1: local-only persistence
- Future: sync protocol (p2p or relay) in V2+

### No Cloud Accounts
- No login required
- Privacy-focused design

## Platform Decisions

### macOS Minimum Version: 14+ (Sonoma)
- Baseline for modern SwiftUI features
- Required APIs available

### No Default Global Hotkey
- User-configurable via settings in V1
- Prevents conflicts with existing workflows

### Auto-Paste Deferred
- V1 focuses on: listen → preview → select → copy
- Auto-paste (copy+paste) requires accessibility permissions
- Deferred to avoid permission friction

## Privacy Decisions

### Privacy Mode Behavior (V1)
- When enabled: stops capturing new clipboard items
- Future: option to hide existing items

### Privacy Policy Default
- Default sync/capture concept deferred to V2
- For V1, privacy mode stops capturing new items

## Architecture Decisions

### Handler Registration Pattern
For clipboard content processing:
- Separates detection from processing logic
- Enables extensible type support without core changes
- Each handler decides what to do (store/OCR/ignore)

See [architecture/clipboard-handler.md](../architecture/clipboard-handler.md) for details.

### SwiftUI + Go Core Architecture
- UI: Swift/SwiftUI for native macOS experience
- Core: Go library for cross-platform data/logic
- C ABI: Bridge between Swift and Go

## Data Model Decisions

### Single Directory Persistence
- All data under `~/Library/Application Support/ClipboardTool/`
- Configurable by user
- Supports migration and backup

### Soft Delete with Physical Delete Option
- Default: soft delete via `deleted_at_ms` column
- Optional: physical delete for permanent removal
- Physical delete also removes associated blob files

### Retention Policy
- Keep last N items (default: 500)
- Pinned items never automatically deleted
- Delete oldest non-pinned when exceeding limit

## UI/UX Decisions

### Popover-Style Floating Panel
- NSPanel instead of full window
- Centered on screen (first open)
- Remembers position (subsequent opens)
- Hides on deactivate

### Keyboard-First Design
- Focus search on open
- Up/Down to navigate list
- Enter to paste
- Esc to close

### Preview Layout Modes
- Three layout modes: Preview Right (default) / Left / Bottom
- Single button cycles through layouts
- No layout picker menu in V1

## Pending Decisions

The following items are still under consideration:

### Global Hotkey and Paste Automation Scope
- User-configurable global hotkey: implemented ✅
- Auto-paste via synthetic keystrokes: partially implemented
- Requires accessibility permissions

### Launch at Login Behavior
- Implementation depends on signed/installed app
- May require SMAppService.mainApp
- Currently implemented via `SMAppService.mainApp` ✅

## Related Documentation
- [spec/](spec/) - Product specifications
- [design/](design/) - UI/UX and feature designs
- [architecture/](architecture/) - Technical architecture
