# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by *Keep a Changelog*.

## [0.1.0] - 2026-02-01
### Added
- Go core library (C ABI) with SQLite persistence under a single data directory.
- Clipboard text capture pipeline (canonicalize, hash, dedupe, retention).
- CRUD-style APIs: add/list/search/get_text, pin, soft-delete, clear-all.
- Settings APIs: privacy mode, retention max.
- Maintenance APIs: optimize, vacuum, integrity_check.
- Directory-based export/import with optional backup on import.
- macOS (SwiftUI) menu-bar app scaffold (SwiftPM):
  - Open window + focus handling, ESC to close.
  - Clipboard polling (NSPasteboard changeCount) with user-adjustable interval.
  - List/search UI + preview panel; Enter/Cmd+C to copy.
  - Preview toggles (wrap + monospace) default ON.
  - Settings window: data folder open, privacy/retention, stats, maintenance, export/import.
  - Global hotkey (Carbon RegisterEventHotKey) via preset picker + enable toggle.
- Specs & project docs: SPEC.md, SPEC_CORE_ABI.md, TASKS.md, BACKLOG.md.

### Notes
- Current macOS app is SwiftPM-based executable; converting to a distributable `.app` is tracked in BACKLOG.
