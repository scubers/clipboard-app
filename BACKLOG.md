# Clipboard Tool — Backlog / Future Improvements

This file tracks deferred work and known improvements (due to prioritization or deliberate scope choices), so we can come back and complete/optimize later.

## Core (Go)
- [x] Upgrade search to prefer **FTS5** when available (better relevance, speed, tokenization), with LIKE fallback.
  - Note: when FTS5 is unavailable, search falls back to `LIKE` (still no literal search for `%` and `_`).
- [x] Include deleted in search results (implemented as `ct_items_search_json_ex`).
- [x] Add per-item `sourceApp` capture on macOS (best-effort via frontmostApplication.localizedName).
- [x] Improve error model: make `ct_last_error_message` thread-local (keyed by pthread_self).
- [x] Replace handle table with stronger lifetime guarantees (use real C-allocated opaque pointers as handles).
- [ ] Add DB maintenance APIs:
  - [x] vacuum/optimize (done)
  - [x] export/import (directory-based)
  - [x] integrity_check helper

## macOS App (SwiftUI)
- [x] Build a runnable `.app` bundle for local testing (scripted).
- [x] Convert SwiftPM project into a proper Xcode `.app` project for distribution (XcodeGen).
- [ ] Real menu bar UI + window/panel behavior (popover/panel), plus better keyboard navigation (search→list focus transitions).
  - In progress: switched main window to a floating NSPanel that hides on deactivate.
- [x] User-configurable global hotkey (preset picker + enable toggle).
- [x] Improve hotkey UX: record arbitrary key combo (instead of presets).
- [ ] (Optional) Move UI-side settings persistence from UserDefaults to core `settings.json` (single-dir portability).
- [x] Launch at login toggle (via `SMAppService.mainApp`; may require signed/installed app).
- [x] Better preview UI for long text (wrap toggle, monospace toggle).
- [ ] Preview extras: search-within-preview, jump-to-top/bottom, copy-without-format.

## UI Behavior (Popover / Focus)
- [ ] Raycast-like focus behavior: when activating the panel over another app (e.g., WeChat input), allow typing into our search while the underlying app still *appears* focused (caret still blinking / traffic lights still colored). Investigate feasibility (likely via key-window activation tradeoffs vs CGEventTap-based input capture). **Deferred for now; keep current behavior.**

## Sync (V2+)
- [ ] Multi-device sync protocol (p2p or relay).
- [ ] Privacy Mode semantics for sync/capture.

---

## Notes
- When any of the above items becomes “active work”, update the relevant spec files and tasks accordingly.
