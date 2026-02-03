# ClipboardTool UI Spec (Popover v1)

> Status: **design locked** (no code changes implied by this doc)

## Goals
- Modern, high-end macOS popover UI (Raycast-like) with **frosted glass / translucency**.
- **Follow system appearance** (Light/Dark) automatically.
- Keyboard-first efficiency with minimal chrome.
- Enable future cross-device sync without UI regressions (data dir already configurable).

## Window / Panel Behavior
- **Presentation:** Popover-like floating panel (NSPanel style), not a full traditional window.
- **Draggable:** User can drag the panel.
  - Drag region: top ~10px handle + optionally empty areas.
- **Initial placement (first ever open):** on the **current screen**, centered **slightly top**.
- **Restore placement (subsequent opens):** restore last window frame/position.
- **Restore list state (subsequent opens):** restore:
  - last selected item id
  - list scroll position (so it opens where user last viewed)

## Layout Modes (Preview Position)
We define layout modes by the **preview pane position**:
- **R** = Preview Right (default): List on left, Preview on right
- **L** = Preview Left: Preview on left, List on right
- **B** = Preview Bottom: List on top, Preview at bottom

### Layout Switch Button
- Location: **fixed** at the far-right of the Search row (does not move in any layout).
- Interaction: **single click cycles layout** with no popover/menu:
  - **R → L → B → R ...**
- Icon: **SF Symbols**-style icon representing the **current layout**.
  - After cycling, icon updates to reflect the new current layout.
- Optional: tooltip can show “Layout: Preview Right/Left/Bottom”.

## Top Chrome
- No dedicated title row (remove “ClipboardTool” header line).
- Keep UI minimal; rely on frosted material + subtle separators.

## Search Row
- Left: Search field.
- Right: quick filters (pills) remain on the same row:
  - **All / Text / Images**
- Rightmost: Layout switch button (see above).

## List Item Visuals
- Each row shows:
  - Type indicator (text/image)
  - Title/summary
  - Secondary metadata line: source app (icon + name), type label (Text/Image)
  - Right side: time (weak color)
- **Pinned indicator:** use a subtle **pin glyph** in the list (not a loud badge).
- Selected row: subtle accent background.

## Preview Pane
- Card style inside the popover (rounded, subtle border).
- Header includes:
  - “Preview” title
  - source app + time
  - pinned badge can appear here (stronger than list)
- Body:
  - Text preview uses readable monospace option when appropriate.
  - Image preview should fit/scale with scroll if needed.
- Actions (bottom-right): Copy / Paste.

## Footer / Hints
- Optional hint bar at bottom:
  - shows keyboard shortcuts (subtle)
  - item count on right

## Keyboard
- Focus search on open.
- Default-select first item on open (already implemented previously).
- Up/Down navigates list immediately.

## Non-Goals (for this iteration)
- No additional top toolbar.
- No layout picker menu (cycle only).
- No new settings UI for layout yet (optional later).
