# Clipboard Tool — V1 Completed Tasks

This file tracks completed milestones and features.

## Milestone 0: Repo skeleton ✅
- [x] Create repo layout: `macos/` (SwiftUI app), `core/` (Go), `docs/`.
- [x] Add build scripts for Go → C library.

## Milestone 1: Go core (local persistence) ✅
- [x] Define data model (ClipboardItem).
- [x] Implement SQLite schema + migrations.
- [x] Implement insert item (text only first).
- [x] Implement list items (pagination).
- [x] Implement search (prefer FTS5 with LIKE fallback).
- [x] Implement retention policy (max N, keep pinned).
- [x] Implement privacy mode flag in settings.
- [x] Implement pin/unpin.
- [x] Implement soft delete.
- [x] Extend search to support includeDeleted (without breaking ABI).
- [x] Implement clear-all history API.
- [x] Implement DB maintenance APIs (vacuum/optimize).
- [x] Implement stats API.

## Milestone 2: SwiftUI macOS app ✅
- [x] Menu bar app scaffold (SwiftPM buildable).
- [x] Settings screen (data dir, retention, poll interval, privacy toggle).
- [x] User-configurable global hotkey (no default).
- [x] Clipboard polling loop (NSPasteboard) + user-configurable interval.
- [x] Dedupe consecutive identical (core) + suppress self-copy feedback loop (UI).
- [x] List UI + search box.
- [x] Preview selected item (text).
- [x] Copy selected item back to clipboard (Enter / Cmd+C).
- [x] Auto-focus search field on open.
- [x] Keyboard: Down arrow from search focuses list + selects first item.

## Milestone 3: Packaging & DX ✅
- [x] Launch at login toggle.
- [x] DB integrity check helper.
- [x] Export/import by moving the single data directory (core API + Settings UI).
- [x] Build runnable `.app` bundle for local testing (scripted).
- [x] Convert SwiftPM project into a proper Xcode `.app` project (XcodeGen).

## Acceptance Criteria (V1) ✅
- [x] Captures text clipboard reliably.
- [x] Search works on last 500 items.
- [x] All persistent data lives under one directory.
- [x] Privacy mode stops capturing.

## V1.1 Enhancements ✅
- [x] Add image clipboard support (PNG, TIFF, JPEG, WebP)
- [x] Implement clipboard handler architecture with type-based routing
- [x] Improve hotkey UX: record arbitrary key combo (instead of presets)
- [x] Better preview UI for long text (wrap toggle, monospace toggle)
- [x] Switch main window to floating NSPanel that hides on deactivate
