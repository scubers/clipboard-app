# Clipboard Tool — Dev Notes

## Build plan (high level)
- `core/` Go module exports C ABI (`-buildmode=c-shared`) -> `libclipboardtool.dylib` + `clipboardtool.h`
- `macos/` SwiftUI app links the library and calls the C functions.

## Development rule (mandatory)
**After every change, verify builds are green** (don’t leave the repo in a broken build state):
- Core + ABI/link smoke test:
  ```bash
  ./scripts/build_macos_smoketest.sh
  ```
- Xcode project build (generated via XcodeGen):
  ```bash
  ./scripts/build_macos_xcode.sh
  ```
- Local runnable .app bundle (quick manual verification):
  ```bash
  ./scripts/build_macos_app_bundle.sh
  open -n dist/Pasty.app
  ```

## UI / UX notes

### Hotkey → panel → paste back to previous app (best-effort)
- When triggered via global hotkey, the app remembers the current frontmost app.
- Press **Enter** in the panel to:
  1) copy selected item into the system clipboard
  2) switch back to the previous app
  3) send a synthetic **Cmd+V** to paste into the previous app's focused input.

**Permissions:** automatic paste uses synthetic keystrokes and requires macOS Privacy permissions:
- System Settings → Privacy & Security → **Accessibility**
- (Sometimes) **Input Monitoring**

If permission is missing, the copy-to-clipboard still works, but auto-paste will not work.

### Search debounce
Search refresh is debounced while typing to avoid excessive queries.

### Remove history (physical delete)
In Settings, "Remove History" will physically delete rows from SQLite. For non-text items (images), it also deletes the stored blob files under:
`~/Library/Application Support/ClipboardTool/data/blobs/`
This is irreversible.

## Next steps
1) Improve "focus not lost" behavior: explore a non-activating panel or alternative event routing.
2) Make paste-to-previous-app more robust (retry paste after activation; optionally use AX to insert text directly).
3) Better keyboard navigation: Up/Down in list + Enter paste + Esc close.

