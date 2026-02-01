# Pasty (macOS) — Architecture

Status: draft (feature-first)

This document defines the **directory layout**, **dependency rules**, and **coding constraints** for the macOS app so we can keep shipping features without turning the codebase into spaghetti.

## Goals
- **Feature-first UI**: keep each feature’s UI code (Views + ViewModels) together.
- **Layered foundation**: shared logic lives in `Domain/`, `Data/`, `Services/`, `Infrastructure/`.
- **Clear boundaries**: UI does not talk directly to C/Go core or do file IO.
- **Scalable**: adding new features (and new platforms later) should not require rewrites.

---

## Directory layout (target)

Root: `macos/ClipboardToolApp/Sources/ClipboardToolApp/`

```
App/
  ClipboardToolApp.swift
  AppDelegate.swift

UI/
  Components/
    (shared SwiftUI components)
  Features/
    MainPanel/
      Views/
        ContentView.swift
        ItemRowView.swift
        PreviewCardView.swift
      ViewModels/
        MainPanelViewModel.swift
    Settings/
      Views/
        SettingsView.swift
        SettingsPages.swift
        SettingsSidebarView.swift
      ViewModels/
        SettingsViewModel.swift

Store/
  AppStore.swift
  PanelCoordinator.swift

Domain/
  Models/
    (pure models/enums)
  DTO/
    (transport-only structs)

Data/
  CoreBridge/
    CoreBridge.swift         # @_silgen_name declarations only
    CoreErrors.swift
  Clients/
    CoreClient.swift         # thin Swift wrapper around bridge
  Repositories/
    ClipboardRepository.swift
    CoreClipboardRepository.swift

Services/
  ClipboardCapture/
    PasteboardMonitor.swift
  OCR/
    OCRService.swift
    OCRQueueManager.swift
  Hotkey/
    HotkeyManager.swift
    HotkeyRecorder.swift
    HotkeyCapture.swift
  System/
    LaunchAtLoginManager.swift
    AppRelauncher.swift

Infrastructure/
  Paths/
    AppPaths.swift
  Config/
    MacOSConfig.swift        # Codable struct(s)
    MacOSConfigStore.swift   # reads/writes <sharedDir>/config/macos.json
  Notifications/
    AppNotifications.swift
```

Notes:
- `AppStore` is the app-level state container / dependency injection point.
- `PanelCoordinator` centralizes window/panel behavior (multi-screen placement, show/hide, focus).

---

## Dependency rules (hard constraints)

### Allowed dependency direction
- **Views** → their **Feature ViewModels** → (**AppStore**, **Repositories**, **Services**)
- **Repositories** → **CoreClient** → **CoreBridge**
- **Services** may depend on **Infrastructure** and **Domain**, but should not depend on SwiftUI.

### Forbidden dependencies
- UI **must not** call `@_silgen_name` / C bridge functions directly.
- UI **must not** read/write config files directly.
- ViewModels **must not** import other feature’s Views/ViewModels.

### How features communicate
Feature-to-feature interaction must happen via one of:
- `AppStore` (shared state + intent methods)
- `PanelCoordinator` (UI presentation / windowing)
- shared `Domain/` models
- shared `Services/` or `Repositories/`

This prevents circular dependencies and keeps features separable.

---

## What is stored where (persistence policy)

### UserDefaults (per-machine; not synced)
Only for device/UI state that should *not* sync:
- window placement (`panelFrame`), last active display id
- ephemeral UI state (selected item, list filter)
- custom hotkey settings (explicitly **not** synced for now)

### Shared directory (synced)
- Go/core owns: `<sharedDir>/config/settings.json` (cross-platform core settings)
- macOS app owns: `<sharedDir>/config/macos.json` (macOS-only settings)

macOS settings file should be **pretty printed** and **sorted keys**.

---

## Responsibilities

### AppStore
- Loads macOS config from `<sharedDir>/config/macos.json`
- Publishes syncable settings (`@Published`)
- Holds references to repositories/services
- Provides high-level intent methods for UI (e.g. refresh data, toggle monitoring)

### PanelCoordinator
- Owns panel show/hide behavior
- Implements multi-display placement rules
- Sets focus on open (search focus)
- Avoids duplicating window logic across Views

### ViewModels
- No file IO
- No direct C bridge calls
- Use repositories/services via AppStore
- Own feature state + errors

---

## Xcode project maintenance (required)

We maintain `macos/Xcode/ClipboardTool.xcodeproj` using **XcodeGen**.

- Source of truth: `macos/Xcode/project.yml`
- Generator script: `scripts/gen_xcodeproj.sh` (requires `xcodegen`)

Rules:
- Do **not** hand-edit `project.pbxproj` unless absolutely necessary.
- After moving/adding Swift files, re-generate the project:

```bash
./scripts/gen_xcodeproj.sh
```

- Commit the regenerated `.xcodeproj` along with the code changes.

---

## Add-a-feature checklist
1. Create `UI/Features/<Feature>/Views` and `UI/Features/<Feature>/ViewModels`.
2. If you need shared logic, put it in `Domain/` / `Services/` / `Data/` instead of importing other features.
3. Add new persistence:
   - if syncable macOS-only → `macos.json` via `MacOSConfigStore`
   - if core/cross-platform → add to Go core settings + expose API
   - if device-only → UserDefaults
4. Ensure build still works with SwiftPM, Xcode project (XcodeGen), and CI release workflow.
