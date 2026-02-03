# SPEC — Delete Item from History (v1)

Status: **Design Review**

## Goal
Allow users to permanently delete individual clipboard history items from the list, including any associated blob files (e.g., images stored on disk).

## Decisions (to be locked)
1. Delete trigger: **Right-click context menu** + **Preview pane action** ✅
2. Physical deletion: **Yes** — delete from SQLite + blob files ✅
3. Confirmation: **Required** — non-pinned items require simple confirmation ✅
4. Pinned items: **Extra confirmation** — require explicit "Delete pinned item?" alert ✅
5. Keyboard shortcut: **Delete key** (Backspace) for selected item ✅
6. Visual feedback: **Fade-out animation** before removal ✅

---

## Data Model (SQLite)

### New API (Go Core)

Add soft delete API (already exists in SPEC_CORE_ABI.md):
- `ct_items_soft_delete(core, id, deletedAtMs)` — marks item as deleted

Add new physical delete API:
```go
// ct_items_delete_physical(core, id) -> int32
// - Deletes the item row from SQLite
// - For image items, deletes the associated blob file from data/blobs/
// - Returns CT_OK on success, error code on failure
```

### Blob Cleanup

Blob file location (from SPEC_CORE_ABI.md):
- `${dataDir}/data/blobs/` — image storage

Blob file naming:
- Core uses content_hash as filename (e.g., `a1b2c3d4...png`)

When deleting an image item:
1. Get `content_hash` from the item row
2. Delete blob file if exists
3. Delete item row

---

## UI Behavior

### Context Menu (List Item)

**Trigger:** Right-click on any list item

**Menu items:**
```
┌─────────────────────┐
│ Copy              │
│ Paste             │
│ ─────────────────  │
│ Pin / Unpin      │
│ Delete…           │  ← New
└─────────────────────┘
```

**Delete… item behavior:**
- Click "Delete…" → confirmation dialog
- After confirmation:
  1. Fade-out animation on list row
  2. Remove item from filteredItems
  3. Refresh list (or optimistic update)
  4. Physical delete via core API

### Preview Pane Actions

**Location:** Bottom-right of Preview pane (same area as Copy/Paste buttons)

**Add new button:** Delete

**Preview actions row (updated):**
```
┌────────────────────────────┐
│                         │
│         [Preview]         │
│                         │
│         [Content]         │
│                         │
│      [Copy] [Paste] [Delete]  ← Add Delete
└────────────────────────────┘
```

**Button style:**
- Secondary button style (bordered, not prominent)
- Icon: `trash` (SF Symbols)
- Label: "Delete" (short form)
- Disabled when: no item selected

### Keyboard Shortcuts

| Key | Action | Confirm Required |
|------|---------|------------------|
| **Backspace** | Delete selected item | Yes |
| **Delete key** (forward delete) | Delete selected item | Yes |
| **Cmd+Backspace** | Delete selected item | Yes |

**Behavior:**
- Only affects currently selected item
- Requires same confirmation as context menu
- Works in search mode (filtered list)

---

## Confirmation Dialogs

### Standard Delete (Non-pinned)

**Title:** "Delete item?"

**Message:** "This will permanently delete this item from your clipboard history."

**Buttons:**
- **Delete** (primary, destructive red)
- **Cancel** (secondary)

### Pinned Item Delete

**Title:** "Delete pinned item?"

**Message:** "This item is pinned. Deleting it will permanently remove it from your clipboard history."

**Buttons:**
- **Delete Anyway** (primary, destructive red)
- **Cancel** (secondary)

---

## Visual Feedback

### Fade-out Animation

When delete is confirmed:
1. List row starts with `.opacity(1)`
2. Animate to `.opacity(0)` over 200ms
3. Remove item from list
4. Trigger physical delete

### Selection Handling After Delete

When selected item is deleted:
- Select next available item (if any)
- If no items remain: `selectedID = nil`
- Preview pane shows "(No selection)"

---

## Error Handling

### Core API Failures

If `ct_items_delete_physical` returns error:
- Show error in preview pane (same location as other VM errors)
- Keep item in list (don't remove visually)
- Error message: "Failed to delete item: [error description]"

### File System Errors

If blob file deletion fails:
- Still delete database row (keep DB consistent)
- Log error to console
- Don't show user-visible error (silent cleanup attempt next vacuum/optimize)

---

## Keyboard Navigation Integration

**Existing key handling (PanelCoordinator.swift):**
```swift
case 53: // ESC → close panel
case 126: // Up arrow
case 125: // Down arrow
case 36, 76: // Enter / Return → paste
```

**Add new cases:**
```swift
case 51: // Backspace → delete
case 117: // Forward delete → delete
    // Show confirmation, then delete
```

**Conflict check:**
- Backspace in search field: should NOT trigger item delete
- Only trigger when focus is on list (not search)
- Implementation: check `focusTarget == .list` before handling delete

---

## Database Impact

### Schema Changes

**No schema changes required.**
- Existing `deleted_at_ms` column remains
- New physical delete API handles file cleanup

### Maintenance

Existing vacuum/optimize already handles:
- Cleaning up orphaned blob files (future enhancement)
- Reclaiming space after deletions

---

## Privacy

- Delete is local-only
- No sync involved (future v2+ would sync deletions)
- Physical file deletion ensures no recovery from disk

---

## Future (v1.1+)

- **Bulk delete:** Select multiple items and delete at once
- **Undo delete:** 30-second grace period to undo accidental deletions
- **Smart delete suggestion:** Suggest deleting old/unpinned items after X days

---

## Acceptance Criteria

- [ ] Right-click on list item shows "Delete…" option
- [ ] Preview pane has Delete button
- [ ] Backspace/Delete key triggers delete for selected item
- [ ] Confirmation dialog shows for non-pinned items
- [ ] Extra confirmation shows for pinned items
- [ ] Image items delete blob file from disk
- [ ] Text items delete only database row
- [ ] Fade-out animation plays before removal
- [ ] Selection moves to next item after delete
- [ ] Errors are shown in preview pane
- [ ] Backspace in search field does NOT trigger item delete
