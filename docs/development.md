# ClipboardTool — Development Guide

## Quick Start

### Prerequisites (macOS)

- macOS 14+ (Sonoma)
- Xcode (and Command Line Tools)
- Homebrew
- Go (for compiling core dynamic library)
- XcodeGen (for generating/maintaining Xcode project)

### Bootstrap New Development Environment

Prerequisite: You have cloned the repository.

Run from repository root:

```bash
./scripts/bootstrap_dev_macos.sh
```

If you only want to run SwiftPM/Go build without Xcode build:

```bash
./scripts/bootstrap_dev_macos.sh --skip-xcodebuild
```

The script will:
- Install dependencies (`go`, `xcodegen`)
- Generate Xcode project (XcodeGen)
- Build Go core dynamic library
- `swift build` (SwiftPM)
- Optional `xcodebuild` (Xcode Debug build)

---

## Build Workflow (Recommended)

### Core + ABI/link smoke test
```bash
./scripts/build_macos_smoketest.sh
```

### Xcode project build (generated via XcodeGen)
```bash
./scripts/build_macos_xcode.sh
```

### Local runnable .app bundle (quick manual verification)
```bash
./scripts/build_macos_app_bundle.sh
open -n dist/Pasty.app
```

### Using Skills (OpenClaw)

Quick verify build:
```bash
skill: macos-verify-build
```

This automates the macOS Development Workflow steps.

---

## Development Rules

### Mandatory Build Verification

**After every change, verify builds are green** (don't leave the repo in a broken build state):
1. `build_macos_smoketest.sh` - Core + ABI/link verification
2. `build_macos_xcode.sh` - Xcode project build
3. `build_macos_app_bundle.sh` - Local .app bundle for testing

### Recommended Workflow After Code Changes

When modifying macOS app code (Swift/SwiftUI), follow this workflow:

1. **Generate Xcode project** (if file structure changed):
   ```bash
   ./scripts/gen_xcodeproj.sh
   ```

2. **Build and verify**:
   ```bash
   ./scripts/build_macos_app_bundle.sh
   ```

3. **Run and test** (optional):
   ```bash
   open -n dist/Pasty.app
   ```

**Why this workflow?**
- `gen_xcodeproj.sh` ensures file structure is correct before building
- `build_macos_app_bundle.sh` handles app assembly and produces runnable `.app`
- No manual `xcodebuild` commands → avoids errors and saves tokens
- Consistent with CI/CD pipeline (uses same scripts)

**When is each step required?**
- **gen_xcodeproj.sh**: Required when adding/removing/moving Swift files
- **build_macos_app_bundle.sh**: Required when any code changes (to verify build)
- **Running the app**: Optional, for quick manual verification

---

## Project Architecture

### High Level
- `core/` Go module exports C ABI (`-buildmode=c-shared`) → `libclipboardtool.dylib` + `clipboardtool.h`
- `macos/` SwiftUI app links the library and calls the C functions

See [architecture/macos.md](../architecture/macos.md) for detailed macOS architecture and directory structure.

---

## Xcode Project Maintenance

We maintain `macos/Xcode/ClipboardTool.xcodeproj` using **XcodeGen**.

- Source of truth: `macos/Xcode/project.yml`
- Generator script: `scripts/gen_xcodeproj.sh` (requires `xcodegen`)

**Rules:**
- Do **not** hand-edit `project.pbxproj` unless absolutely necessary.
- After moving/adding Swift files, re-generate the project:
  ```bash
  ./scripts/gen_xcodeproj.sh
  ```
- Commit regenerated `.xcodeproj` along with code changes.

---

## UI / UX Notes

### Hotkey → Panel → Paste Back to Previous App (best-effort)

When triggered via global hotkey, the app remembers the current frontmost app.

Press **Enter** in the panel to:
1) Copy selected item into the system clipboard
2) Switch back to the previous app
3) Send a synthetic **Cmd+V** to paste into the previous app's focused input.

**Permissions:** Automatic paste uses synthetic keystrokes and requires macOS Privacy permissions:
- System Settings → Privacy & Security → **Accessibility**
- (Sometimes) **Input Monitoring**

If permission is missing, the copy-to-clipboard still works, but auto-paste will not work.

### Search Debounce
Search refresh is debounced while typing to avoid excessive queries.

### Remove History (Physical Delete)
In Settings, "Remove History" will physically delete rows from SQLite. For non-text items (images), it also deletes the stored blob files under:
`~/Library/Application Support/ClipboardTool/data/blobs/`
This is irreversible.

---

## Related Documentation

- [README.md](../README.md) - Project overview and user-facing documentation
- [spec/](../spec/) - Product specifications
- [design/](../design/) - UI/UX and feature design specifications
- [architecture/](../architecture/) - Technical architecture documentation
- [planning/](../planning/) - Tasks and backlog
