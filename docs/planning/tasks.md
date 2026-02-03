# Clipboard Tool — V1 Current Tasks

This file tracks active milestones and tasks in progress.

## Milestone 4: Advanced Features

### OCR Image Search
- [ ] Implement Vision framework OCR service in macOS app
- [ ] Add OCR text columns to items table (ocr_text, ocr_status, ocr_updated_at_ms)
- [ ] Implement core API: `ct_items_set_ocr_text()`
- [ ] Update search to include OCR text matching (LIKE query against ocr_text)
- [ ] Add OCR match indicator in UI for image items
- [ ] Implement on-demand OCR trigger during search
- [ ] Add OCR queue manager for batch processing

### Delete Item (Physical)
- [ ] Implement core API: `ct_items_delete_physical()`
- [ ] Add blob file cleanup on physical delete
- [ ] Add "Delete" button to preview pane
- [ ] Add "Delete…" option to list item context menu
- [ ] Implement Cmd+D keyboard shortcut for delete
- [ ] Add confirmation dialogs (standard and pinned)
- [ ] Implement fade-out animation before removal
- [ ] Handle errors gracefully

### Item Tags
- [ ] Design and create tags table (id, name, color_hex)
- [ ] Create item_tags junction table (many-to-many)
- [ ] Implement core APIs:
  - [ ] `ct_items_add_tag()`
  - [ ] `ct_items_remove_tag()`
  - [ ] `ct_items_get_tags()`
  - [ ] `ct_tags_list()`
  - [ ] `ct_tags_rename()`
  - [ ] `ct_tags_delete()`
- [ ] Update search to include tag matching
- [ ] Implement tag display in list items (colored pills)
- [ ] Implement tag display in preview pane
- [ ] Create tag editor popover (Cmd+T)
- [ ] Add tag filter pills in search bar
- [ ] Implement tag color palette (16 distinct colors)

### Additional UX Improvements
- [ ] Minimal logging implementation
- [ ] Preview extras: search-within-preview, jump-to-top/bottom
- [ ] (Optional) Raycast-like focus behavior investigation
- [ ] (Optional) Move UI-side settings to core settings.json for single-dir portability

---

## Related Documentation
- [Tasks Completed](tasks-completed.md) - Completed milestones and features
- [Backlog](backlog.md) - Future improvements
