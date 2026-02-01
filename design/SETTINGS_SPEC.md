# ClipboardTool Settings Panel — Spec (Sidebar)

Status: **Design locked** (do not change visuals unless spec is updated)

## High-level
- Style: modern macOS settings window, **sidebar navigation** + right content, rounded cards.
- Appearance: follow system Light/Dark.
- No settings-search field.
- Right header: page title + short hint + version pill (e.g. `v0.1`).

## Navigation (Sidebar)
Single-level list (no extra groups):
1. General
2. Appearance
3. Preview
4. Storage
5. Shortcuts
6. Capture
7. Advanced

## Common layout rules
- Each page is **self-contained** (no mixing settings across tabs).
- Settings are grouped into **rounded cards** (“sections”).
- Right-side controls are **right-aligned**.
- Use native controls where possible (Toggle, Slider, SegmentedControl).

---

## General
### Startup
- Launch at login (Toggle)

### Monitoring
- Enable monitoring (Toggle)
- Poll interval (Slider + value pill, ms)

### Layout
- Default preview layout: **Segmented control** `L | R | B`
  - Meaning: preview position **Left / Right / Bottom**
  - Default value: **R**
  - Note text: Popover cycles layouts in order `R → L → B`.

---

## Appearance
### Background
- Tint (readability) (Slider + percentage)
  - Higher tint improves readability on bright backgrounds.

### Window
- Hide traffic lights (Toggle)
  - Matches popover chrome-minimal style.

---

## Preview
### Text
- Wrap (Toggle)
- Monospace (Toggle)

### Images
- Fit mode (read-only pill for now): `Scale to fit`

---

## Storage
### Directories
- Local config path (read-only path)
- Shared directory path (read-only path)
- Actions:
  - Choose…
  - Reset
  - Open

### Restart (always visible)
- Text: “Changing the shared directory requires restarting the app to ensure all components use the new location.”
- Buttons (macOS-like copy):
  - **Restart Now**
  - **Not Now**

---

## Shortcuts
### Global hotkey
- Toggle popover
  - Show current hotkey as a pill
  - Button: Change…

### Recording state (system-like)
When Change… is active:
- Row shows:
  - Label: Recording…
  - Primary action text/pill: Press keys now
  - Button: Cancel
- Help text:
  - Press Esc to cancel.
  - Press Backspace to clear.

### Behavior
- Enter key (read-only pill): Paste
  - Help text: Press Enter to paste the selected item into the previous app.

---

## Capture
### Privacy
- Privacy mode (Toggle)
  - Help: When enabled, the app stops capturing new clipboard items.

### Retention
- Max items (Slider + value pill)

---

## Advanced
### Database
- Optimize / Vacuum (buttons)
- Integrity check (button)

### Transfer
- Export… (button)
- Import… (button) + Keep backup (toggle/pill)

### Danger zone (only here)
- Remove history:
  - Remove (keep pinned)
  - Remove all
- Always requires confirmation (modal alert).
- Help: Permanently deletes database rows and blob files.
