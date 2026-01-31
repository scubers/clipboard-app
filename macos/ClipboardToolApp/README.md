# ClipboardToolApp (macOS SwiftUI)

This is a **SwiftPM**-based macOS menu bar scaffold for ClipboardTool.

## Build
From repo root:

```bash
./scripts/build_macos_app_spm.sh
```

## Run (debug)
After build, run the produced executable:

```bash
cd macos/ClipboardToolApp
swift run
```

Notes:
- The Go core dylib is built and copied into `Vendor/core/` for linking.
- For a distributable `.app` bundle, we will later migrate to an Xcode project (see BACKLOG).
