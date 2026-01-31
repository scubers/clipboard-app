# Clipboard Tool — Dev Notes

## Build plan (high level)
- `core/` Go module exports C ABI (`-buildmode=c-shared`) -> `libclipboardtool.dylib` + `clipboardtool.h`
- `macos/` SwiftUI app links the library and calls the C functions.

## Development rule (mandatory)
**After every change, verify builds are green** (don’t leave the repo in a broken build state):
- Core + smoke test:
  ```bash
  ./scripts/build_all.sh
  ```
- SwiftPM macOS app:
  ```bash
  ./scripts/build_macos_app_spm.sh
  ```
- Xcode project (generated via XcodeGen):
  ```bash
  ./scripts/build_macos_xcode.sh
  ```

## Next steps
1) Create repo skeleton in `~/clawd/clipboard-app/` with `core/` and `macos/`.
2) Implement `ct_core_open/close` and SQLite schema.
3) Implement `ct_items_add_text` + `ct_items_list_json`.
4) SwiftUI app: menu bar + list + preview.

