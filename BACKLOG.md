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
- [ ] Build a runnable `.app` bundle for local testing (scripted).
- [ ] Convert SwiftPM project into a proper Xcode `.app` project for distribution.
- [ ] Real menu bar UI + window/panel behavior (popover/panel), plus better keyboard navigation (search→list focus transitions).
- [x] User-configurable global hotkey (preset picker + enable toggle).
- [ ] Improve hotkey UX: record arbitrary key combo (instead of presets).
- [ ] (Optional) Move UI-side settings persistence from UserDefaults to core `settings.json` (single-dir portability).
- [ ] Launch at login (best done after we ship a real `.app` bundle; SwiftPM exec isn’t ideal).
- [x] Better preview UI for long text (wrap toggle, monospace toggle).
- [ ] Preview extras: search-within-preview, jump-to-top/bottom, copy-without-format.

## Sync (V2+)
- [ ] Multi-device sync protocol (p2p or relay).
- [ ] Privacy Mode semantics for sync/capture.

---

## Notes
- When any of the above items becomes “active work”, update the relevant spec files and tasks accordingly.
