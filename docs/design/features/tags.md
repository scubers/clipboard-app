# SPEC — Item Tags (v1)

Status: **Implemented** ✅

Implementation Date: 2026-02-04
Implementation PR: N/A (local development)

## Goal
Allow users to add tags to clipboard history items for better organization and faster retrieval. Tags are stored in the database and integrated into search functionality.

## Decisions (to be locked)
1. Tag format: **Plain text strings**, no hierarchy ✅
2. Tag limit: **Unlimited** (stored as comma-separated) ✅
3. Tag input: **Inline chips** with Enter/Space completion ✅
4. Tag search: **Tag filter pills** in search bar ✅
5. Tag storage: **New SQLite table** with many-to-many relationship ✅
6. Tag visual: **Colored pills** in list and preview ✅
7. Keyboard shortcut: **Cmd+T** to open tag editor ✅

---

## Data Model (SQLite)

### New Tables

#### `tags`

```sql
CREATE TABLE IF NOT EXISTS tags (
  id TEXT PRIMARY KEY,              -- UUID
  name TEXT NOT NULL UNIQUE,         -- Tag name (e.g., "work", "personal")
  created_at_ms INTEGER NOT NULL,
  color_hex TEXT                     -- Optional color for pill (e.g., "#FF5733")
);

CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);
```

#### `item_tags` (junction table)

```sql
CREATE TABLE IF NOT EXISTS item_tags (
  item_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (item_id, tag_id),
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_item_tags_item ON item_tags(item_id);
CREATE INDEX IF NOT EXISTS idx_item_tags_tag ON item_tags(tag_id);
```

### Existing Table Changes

#### `items` (no schema changes)

- Tags are queried via `item_tags` junction table
- No direct `tags` column needed

---

## Core ABI additions (Go dylib)

### Tag Management

```go
// Add a tag to an item (creates tag if not exists)
ct_items_add_tag(core, itemId, tagName, colorHex) -> int32

// Remove a tag from an item
ct_items_remove_tag(core, itemId, tagId) -> int32

// Get all tags for an item (returns JSON array)
ct_items_get_tags(core, itemId, out_json) -> int32

// Get all tags in the system (returns JSON array, with usage count)
ct_tags_list(core, out_json) -> int32
```

### Search Integration

```go
// Unified search: text, ocr_text, OR tag matching (no special syntax needed)
// Returns JSON array of items matching any of the criteria
// - query: search text (matches text_content, summary, OR ocr_text)
// - If query matches a tag name, returns items with that tag
// - No special "tag:" syntax required
ct_items_search_json(core, query, limit, offset, out_json) -> int32
```

**Search Behavior:**
- Text input matches: `text_content LIKE %query%` OR `summary LIKE %query%` OR `ocr_text LIKE %query%`
- Tag input matches: items that have a tag with name matching query
- No distinction needed between text and tag search — unified behavior

### Tag Management

```go
// Rename a tag (updates all item_tags associations)
ct_tags_rename(core, tagId, newName) -> int32

// Delete a tag (cascade deletes all item_tags associations)
ct_tags_delete(core, tagId) -> int32
```

---

## UI Behavior

### Tag Display in List Item

**Location:** Below summary, in metadata line (same row as source app, type, time)

**Visual:**
- Colored pills (rounded rectangle, subtle border)
- Font size: 11px, semibold
- Padding: horizontal 6px, vertical 3px
- Max visible: 2 tags (show "+N" if more)

**Tag color logic:**
- Auto-assigned colors from palette (16 distinct colors)
- Color based on tag name hash (deterministic)
- Palette: `#FF6B6B` (red), `#4ECDC4` (green), `#45B7D1` (blue), etc.

**Example list row (with tags):**
```
┌─────────────────────────────────────────────────────┐
│ [icon]  Summary text...                    · 2小时前 │
│         [WeChat] · Text · [work] [project] +1 │
└─────────────────────────────────────────────────────┘
```

### Tag Display in Preview Pane

**Location:** Header section, below source app + time

**Visual:**
- Larger pills than in list
- All tags visible (no "+N" truncation)
- Interactive: click pill to filter by that tag

**Example preview header (with tags):**
```
┌─────────────────────────────────────────────────────┐
│ Preview                                        [Pinned] │
│ WeChat · 2小时前                              │
│ [work] [project] [important]                   │
├─────────────────────────────────────────────────────┤
│                                                 │
│              (Content preview)                     │
│                                                 │
├─────────────────────────────────────────────────────┤
│              [Copy] [Paste] [Delete]               │
└─────────────────────────────────────────────────────┘
```

### Tag Editor

**Trigger:** Cmd+T when item is selected

**Presentation:** Popover anchored to Preview pane header (or list item row)

**UI layout:**
```
┌─────────────────────────────────────┐
│ Edit Tags                      ×  │
├─────────────────────────────────────┤
│                                 │
│  [work] [project] [important]   │  ← Existing tags (removable)
│  [+] Add new tag...            │
│                                 │
└─────────────────────────────────────┘
```

**Tag chips in editor:**
- Show all current tags as removable chips
- "×" icon on hover for removal
- Click chip → toggle selection for batch removal

**Add new tag:**
- Text input with placeholder "Add tag..."
- Type tag name + Enter → create new tag
- Space → auto-complete existing tag (if matching)
- Allow custom colors (optional v1.1)

**Keyboard in editor:**
- Escape → close editor without saving
- Cmd+Enter → save and close
- Tab → move to next chip

### Tag Filter Pills in Search Bar

**Location:** Search row, between quick filters (All/Text/Images) and layout button

**Visual:**
- Small pill buttons below main search field
- Show active tags first
- "×" to remove filter

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│ 🔍  Search clipboard...                            │
│                                                     │
│  [All] [Text] [Images]  [work] × [project] ×  [Layout] │
└─────────────────────────────────────────────────────────┘
```

**Interaction:**
- Click tag pill → set search field to tag name and filter by that tag
- "×" on pill → clear tag filter (removes from search input)
- Show active tag pills: currently filtering tags

---

## Search Behavior with Tags

### Unified Search

Search input now matches any of:
- Text content: `text_content LIKE %query%`
- Summary: `summary LIKE %query%`
- OCR text: `ocr_text LIKE %query%`
- Tag names: items that have a tag with name matching query

**No special syntax required** — just type the tag name to filter.

**Examples:**

| Search input | Matches | Result |
|--------------|---------|---------|
| `work` | Text containing "work" OR items tagged "work" | Items with "work" in content or tags |
| `hello` | Text containing "hello" | Items with "hello" in content |
| `invoice` | Text containing "invoice" | Items with "invoice" in content |
| (empty) | (none) | All items (existing behavior) |

### Tag Filter Pills (Quick Filter)

When user clicks a tag pill in search bar:
- Sets search field to tag name (e.g., "work")
- Shows items tagged with that tag
- Tag pill shows active state with "×" to remove

**Behavior:**
- Tag pills are shortcuts for filtering by tag
- Text input still works (can override tag filter)
- Removing tag pill clears search field

---

## Keyboard Shortcuts

| Shortcut | Action | Context |
|----------|---------|----------|
| **Cmd+T** | Open tag editor | Item selected |
| **Escape** | Close tag editor | In tag editor |
| **Cmd+Enter** | Save tags & close editor | In tag editor |
| **Tab** | Navigate between tags | In tag editor |
| **Backspace** | Remove last added tag | In tag editor input |

---

## Context Menu Integration

**Add to existing right-click menu:**

```
┌─────────────────────┐
│ Copy              │
│ Paste             │
│ ─────────────────  │
│ Pin / Unpin      │
│ Add Tags…         │  ← New (Cmd+T)
│ Delete…           │
└─────────────────────┘
```

**"Add Tags…" behavior:**
- Opens tag editor for clicked item
- Selects the item first
- Focuses tag input

---

## Visual Color Palette

Auto-assigned tag colors (16 distinct hues, 50% lightness):

| Hash range | Color | Hex |
|------------|--------|------|
| 0 | Red | #E57373 |
| 1 | Pink | #C2185B |
| 2 | Purple | #9B59B6 |
| 3 | Blue | #007AFF |
| 4 | Cyan | #32ADE6 |
| 5 | Green | #4CD964 |
| 6 | Orange | #FF9500 |
| 7 | Yellow | #FFCC00 |
| 8 | Red Orange | #FF6B6B |
| 9 | Teal | #20B2AA |
| 10 | Lime | #7FE5E8 |
| 11 | Magenta | #AF52DE |
| 12 | Coral | #FF695C |
| 13 | Sky | #38BDF8 |
| 14 | Lavender | #A78BFA |
| 15 | Mint | #34D399 |

**Algorithm:**
```swift
func colorForTag(_ name: String) -> Color {
    let hash = name.utf8.reduce(0) { $0 + $1 }
    let index = hash % 16
    return palette[index]
}
```

---

## Performance Considerations

### Tag Search

Tag queries use indexed tables:
- `idx_item_tags_item` — fast filter by item
- `idx_item_tags_tag` — fast filter by tag
- Junction table ensures efficient JOIN

### Tag Autocomplete

Cache frequently used tags in memory:
- Recent tags (last 20 created)
- Popular tags (top 20 by usage count)
- Serve from cache before querying DB

---

## Error Handling

### Duplicate Tag Names

When adding a tag that already exists:
- Reuse existing tag (don't create duplicate)
- Associate item with existing tag_id
- Show toast: "Tag 'work' already exists"

### Invalid Tag Names

Reject tags that:
- Are empty or whitespace only
- Exceed 50 characters
- Contain commas (reserved as separator)

**Validation error:**
- Show alert: "Invalid tag name"
- Focus input field
- Highlight problematic text

---

## Database Migration

When upgrading to v1 with tags:

```sql
-- Create new tables
CREATE TABLE IF NOT EXISTS tags (...);
CREATE TABLE IF NOT EXISTS item_tags (...);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);
CREATE INDEX IF NOT EXISTS idx_item_tags_item ON item_tags(item_id);
CREATE INDEX IF NOT EXISTS idx_item_tags_tag ON item_tags(tag_id);
```

**No data migration needed** (new feature).

---

## Privacy

- Tags are stored in shared database (sync-ready)
- No cloud API in v1 (local-only)
- Future v2: tags sync across devices

---

## Future (v1.1+)

- **Tag groups/hierarchy** (folders for tags)
- **Smart tags** (auto-tag by source app, by content type)
- **Tag colors** (user-customizable)
- **Tag bundles** (save tag combinations as presets)
- **Bulk tag** (select multiple items, add tags to all)
- **Tag autocomplete** (in search field, not just editor)

---

## Acceptance Criteria

- [x] Cmd+T opens tag editor for selected item
- [x] Tag editor shows existing tags as removable chips
- [x] Typing + Enter adds new tag
- [ ] Typing + Space shows autocomplete suggestions (deferred to v1.1)
- [x] Tags display as colored pills in list items (max 2 + N)
- [x] Tags display as colored pills in preview pane (all visible)
- [x] Tag color is deterministic based on tag name
- [ ] Clicking tag in preview filters list by that tag (deferred to v1.1)
- [ ] Search supports tag filter pills (deferred to v1.1 - unified search works)
- [x] Search with text + tags uses OR logic (unified search)
- [ ] Backspace in search removes active tag filter (deferred to v1.1)
- [x] Right-click has "Add Tags…" option
- [x] Tags are stored in SQLite with junction table
- [x] Tag search uses indexed queries
- [x] Error handling for duplicate/invalid tag names

## Implementation Notes

### Completed Features
1. **Database**: Migrations v6 creates `tags` and `item_tags` tables with indexes
2. **ABI**: 6 new C functions exported (`ct_items_add_tag`, `ct_items_remove_tag`, `ct_items_get_tags`, `ct_tags_list`, `ct_tags_rename`, `ct_tags_delete`)
3. **Search**: Unified search matches text, OCR, and tag names
4. **UI Components**:
   - `TagEditorView.swift` - Popover editor with FlowLayout
   - `Tag.swift` - Data models (`ItemTag`, `TagWithCount`)
   - `ItemRowView.swift` - Shows up to 2 tags with "+N" indicator
   - `PreviewCardView.swift` - Shows all tags in preview pane
5. **Shortcuts**: `Cmd+T` to open tag editor (PanelCoordinator.swift)
6. **Context Menu**: "Add Tags…" option in ItemRowView
7. **Real-time Sync**: Tag changes notify parent view to refresh

### Deferred to v1.1
- Tag filter pills in search bar
- Click-to-filter from preview tags
- Space-triggered autocomplete
- Bulk tag operations
