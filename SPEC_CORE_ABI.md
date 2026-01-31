# Clipboard Tool — Core ABI & Storage Spec (V1)

> V1 is **text-only** and **local-only**.
> SwiftUI macOS app calls into a Go core library through a C ABI.

## 1. Packaging

### 1.1 Go module
Path: `core/`

Build outputs:
- macOS: `libclipboardtool.dylib` (or `.a` static lib)
- Header: `clipboardtool.h`

### 1.2 Swift integration
- Add the produced header to the Xcode project bridging header.
- Link the produced `.dylib` or `.a`.

---

## 2. Error model

All exported functions return an `int32_t` status code:
- `0` = OK
- non-zero = error

### 2.1 Error codes
```c
// General
#define CT_OK 0
#define CT_ERR_UNKNOWN 1
#define CT_ERR_INVALID_ARG 2
#define CT_ERR_IO 3
#define CT_ERR_DB 4
#define CT_ERR_NOT_FOUND 5
#define CT_ERR_BUSY 6
#define CT_ERR_UNSUPPORTED 7

// Settings
#define CT_ERR_SETTINGS 20

// Storage
#define CT_ERR_MIGRATION 30
#define CT_ERR_CORRUPT 31
```

### 2.2 Error message retrieval
Core keeps a thread-local last error message.
- On error, Swift may call `ct_last_error_message()`.

Memory:
- Returned C string is owned by core and valid until next call on same thread.

---

## 3. Memory management

We avoid returning heap pointers that Swift must free except where required.

- `const char*` returned from `ct_last_error_message()` is managed by core.
- For JSON blobs, core allocates a buffer and Swift must free via `ct_free()`.

```c
void ct_free(void* p);
```

---

## 4. Data directory model

V1 requirement: **all app data lives under one directory**.

Default directory (macOS UI decides this):
- `~/Library/Application Support/ClipboardTool/`

Core receives a dataDir path and creates structure:
- `${dataDir}/config/settings.json`
- `${dataDir}/data/clipboard.sqlite`

Core should not write outside `dataDir`.

---

## 5. Settings

Stored at `${dataDir}/config/settings.json`.

### 5.1 Settings schema (JSON)
```json
{
  "version": 1,
  "privacyMode": false,
  "retentionMaxItems": 500,
  "dedupeWindow": 50
}
```

Defaults if missing:
- privacyMode=false
- retentionMaxItems=500
- dedupeWindow=50

---

## 6. SQLite schema (V1)

File: `${dataDir}/data/clipboard.sqlite`

### 6.1 Pragmas
- `journal_mode=WAL`
- `synchronous=NORMAL`

### 6.2 Tables

#### 6.2.1 `items`
Text-only items.

```sql
CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  created_at_ms INTEGER NOT NULL,
  type TEXT NOT NULL, -- 'text'
  summary TEXT NOT NULL,
  text_content TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  source_app TEXT,
  pinned INTEGER NOT NULL DEFAULT 0,
  deleted_at_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_items_created_at ON items(created_at_ms DESC);
CREATE INDEX IF NOT EXISTS idx_items_deleted ON items(deleted_at_ms);
CREATE INDEX IF NOT EXISTS idx_items_pinned ON items(pinned DESC, created_at_ms DESC);
CREATE INDEX IF NOT EXISTS idx_items_hash ON items(content_hash);
```

Notes:
- `summary` is the first N chars of `text_content` with whitespace normalized.
- `content_hash` is SHA-256 of canonical text bytes (UTF-8).

#### 6.2.2 FTS (optional V1)
We can use SQLite FTS5 for better search.
V1 can start with `LIKE` search; if FTS is enabled, use it.

Option A (preferred): FTS5
```sql
CREATE VIRTUAL TABLE IF NOT EXISTS items_fts USING fts5(
  id,
  text_content,
  summary,
  content='items',
  content_rowid='rowid'
);

-- Triggers to keep in sync
CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items BEGIN
  INSERT INTO items_fts(rowid, id, text_content, summary) VALUES (new.rowid, new.id, new.text_content, new.summary);
END;

CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items BEGIN
  INSERT INTO items_fts(items_fts, rowid, id, text_content, summary) VALUES('delete', old.rowid, old.id, old.text_content, old.summary);
END;

CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items BEGIN
  INSERT INTO items_fts(items_fts, rowid, id, text_content, summary) VALUES('delete', old.rowid, old.id, old.text_content, old.summary);
  INSERT INTO items_fts(rowid, id, text_content, summary) VALUES (new.rowid, new.id, new.text_content, new.summary);
END;
```

We will decide at implementation time; keep `LIKE` fallback.

---

## 7. Core public API (C)

### 7.1 Types
```c
#ifdef __cplusplus
extern "C" {
#endif

typedef struct ct_core ct_core;

typedef struct {
  const char* id; // UUID string
  int64_t created_at_ms;
  const char* type; // "text"
  const char* summary;
  const char* source_app; // nullable
  int32_t pinned; // 0/1
} ct_item;

#ifdef __cplusplus
}
#endif
```

### 7.2 Lifecycle
```c
int32_t ct_core_open(const char* data_dir, ct_core** out_core);
int32_t ct_core_close(ct_core* core);
```

Rules:
- `data_dir` must be absolute.
- Creates missing subdirs `config/` and `data/`.
- Runs migrations.

### 7.3 Settings
```c
int32_t ct_settings_get_privacy_mode(ct_core* core, int32_t* out_enabled);
int32_t ct_settings_set_privacy_mode(ct_core* core, int32_t enabled);

int32_t ct_settings_get_retention_max(ct_core* core, int32_t* out_max_items);
int32_t ct_settings_set_retention_max(ct_core* core, int32_t max_items);
```

### 7.4 Insert clipboard text
Swift side will call this after detecting pasteboard change.

```c
// returns CT_OK and sets out_id to newly created item id (malloc'd); caller frees via ct_free
int32_t ct_items_add_text(ct_core* core,
                          const char* text_utf8,
                          const char* source_app,
                          int64_t created_at_ms,
                          char** out_id);
```

Core behavior:
- If privacy mode enabled → return CT_OK but `out_id = NULL` (no-op).
- Canonicalize text:
  - normalize line endings to `\n`
  - trim trailing whitespace
- Compute summary (first 120 chars)
- Compute content_hash (sha256)
- Dedupe:
  - If last item has same hash and created_at within 3 seconds → no-op (out_id NULL)
- Enforce retention after insert.

### 7.5 List
We want pagination.

```c
// Returns JSON array of items (ct_item-like fields). Caller frees via ct_free.
int32_t ct_items_list_json(ct_core* core,
                           int32_t limit,
                           int32_t offset,
                           int32_t include_deleted,
                           char** out_json);
```

JSON element shape:
```json
{
  "id":"...",
  "createdAtMs": 0,
  "type":"text",
  "summary":"...",
  "sourceApp": null,
  "pinned": false
}
```

### 7.6 Search
```c
int32_t ct_items_search_json(ct_core* core,
                             const char* query_utf8,
                             int32_t limit,
                             int32_t offset,
                             char** out_json);

// Extended variant with includeDeleted support (preferred for new callers)
int32_t ct_items_search_json_ex(ct_core* core,
                                const char* query_utf8,
                                int32_t limit,
                                int32_t offset,
                                int32_t include_deleted,
                                char** out_json);
```

Search semantics:
- V1 implementation uses SQLite `LIKE` on `text_content`/`summary`.
- Note: literal searching for `%` and `_` is **not supported** in the V1 `LIKE` fallback (no `ESCAPE` clause).
- `ct_items_search_json` always excludes deleted items.
- `ct_items_search_json_ex` follows `include_deleted`:
  - `0` => exclude deleted (`deleted_at_ms IS NULL`)
  - `1` => include deleted
- (Future) Upgrade to FTS5 when we decide to enable it.

### 7.7 Get full text content
Swift needs to preview the full text.

```c
int32_t ct_items_get_text(ct_core* core,
                          const char* id,
                          char** out_text_utf8);
```

### 7.8 Pin/unpin
```c
int32_t ct_items_set_pinned(ct_core* core,
                            const char* id,
                            int32_t pinned);
```

Behavior:
- Returns `CT_ERR_NOT_FOUND` if id does not exist or is already deleted.

### 7.9 Delete
Soft delete for now.
```c
int32_t ct_items_soft_delete(ct_core* core,
                             const char* id,
                             int64_t deleted_at_ms);
```

Behavior:
- If `deleted_at_ms <= 0`, core uses current time.
- Returns `CT_ERR_NOT_FOUND` if id does not exist or is already deleted.

### 7.10 Clear all
Bulk soft-delete.
```c
// keep_pinned: 0 => delete everything, 1 => keep pinned items
int32_t ct_items_clear_all(ct_core* core,
                           int32_t keep_pinned,
                           int64_t deleted_at_ms);
```

Behavior:
- If `deleted_at_ms <= 0`, core uses current time.
- Only affects rows with `deleted_at_ms IS NULL`.

### 7.11 DB maintenance
```c
int32_t ct_db_vacuum(ct_core* core);
int32_t ct_db_optimize(ct_core* core);

// Returns JSON: {"ok":true,"message":"ok"}
int32_t ct_db_integrity_check_json(ct_core* core,
                                  char** out_json);
```

Notes:
- `ct_db_vacuum` can be slow; call it manually (e.g., after large deletions), not on every launch.
- `ct_db_optimize` runs `PRAGMA optimize`.

### 7.12 Stats
```c
int32_t ct_items_stats_json(ct_core* core,
                            char** out_json);
```

Returns JSON:
```json
{
  "totalItems": 0,
  "activeItems": 0,
  "deletedItems": 0,
  "pinnedActiveItems": 0
}
```

### 7.13 Export / Import (directory-based)
```c
// Export current dataset (settings + sqlite) to dest_dir.
int32_t ct_export_to_dir(ct_core* core,
                         const char* dest_dir);

// Import dataset (settings + sqlite) from src_dir into current dataDir.
// keep_backup: 0 => delete/overwrite, 1 => rename existing files with a backup suffix.
int32_t ct_import_from_dir(ct_core* core,
                           const char* src_dir,
                           int32_t keep_backup);
```

Directory layout expected:
- `config/settings.json` (optional)
- `data/clipboard.sqlite` (required)

---

## 8. Swift responsibilities

- Determine `dataDir` (default + allow user change later).
- Poll NSPasteboard and extract string.
- Determine `sourceApp` (optional; can be null in V1).
- Call `ct_items_add_text`.
- Render list/search via JSON returned from core.
- On selection, call `ct_items_get_text` for preview.
- Copy selected item back to clipboard (Swift writes to NSPasteboard).

---

## 9. Acceptance tests (core)

- Opening core creates directory structure.
- Insert text creates item.
- Dedupe prevents immediate duplicates.
- Retention keeps pinned.
- Search finds substring.
- Privacy mode blocks insert.

