# ClipboardTool — V1 Data Model

This document describes the V1 data model and SQLite schema.

## Data Directory Structure

V1 requirement: **all app data lives under one directory**.

Default directory (macOS UI decides this):
- `~/Library/Application Support/ClipboardTool/`

Core receives a dataDir path and creates structure:
- `${dataDir}/config/settings.json`
- `${dataDir}/data/clipboard.sqlite`
- `${dataDir}/data/blobs/` (image/file blobs)

Core should not write outside `dataDir`.

## Settings Schema

Stored at `${dataDir}/config/settings.json`.

### Settings Schema (JSON)
```json
{
  "version": 1,
  "privacyMode": false,
  "retentionMaxItems": 500,
  "dedupeWindow": 50
}
```

Defaults if missing:
- privacyMode = false
- retentionMaxItems = 500
- dedupeWindow = 50

## SQLite Schema

### Pragmas
- `journal_mode=WAL`
- `synchronous=NORMAL`

### Tables

#### `items` Table

Text-only items in V1.

```sql
CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  created_at_ms INTEGER NOT NULL,
  type TEXT NOT NULL, -- 'text' | 'image' | 'file' | 'html' | 'rtf' | 'unknown'
  summary TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  source_app TEXT,
  pinned INTEGER NOT NULL DEFAULT 0,
  deleted_at_ms INTEGER,
  last_copied_at_ms INTEGER,
  content_ref TEXT, -- blob file path for non-text types
  ocr_text TEXT, -- OCR text for images (truncated to 16k)
  ocr_status INTEGER, -- 0=unknown/pending, 1=done, 2=failed
  ocr_updated_at_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_items_created_at ON items(created_at_ms DESC);
CREATE INDEX IF NOT EXISTS idx_items_deleted ON items(deleted_at_ms);
CREATE INDEX IF NOT EXISTS idx_items_pinned ON items(pinned DESC, last_copied_at_ms DESC, created_at_ms DESC);
CREATE INDEX IF NOT EXISTS idx_items_hash ON items(content_hash);
```

**Notes:**
- `summary` is the first N chars of text/image preview.
- `content_hash` is SHA-256 of canonical content bytes (UTF-8 for text, binary for images).
- Default ordering: `pinned DESC, last_copied_at_ms DESC, created_at_ms DESC`

### OCR Columns (Added for Image Search)

- `ocr_text TEXT` — OCR plain text (UTF-8). Stored for `type='image'` only, truncated to 16384 characters.
- `ocr_status INTEGER` — 0=unknown/pending, 1=done, 2=failed.
- `ocr_updated_at_ms INTEGER` — Last time OCR text was produced.

### FTS5 Table (Optional V1)

We use SQLite FTS5 for better search when available.

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

If FTS5 is unavailable, search falls back to SQLite `LIKE` on `text_content` and `summary`.

## Blob Storage

### Image/File Blobs

Stored under `${dataDir}/data/blobs/`:

- File naming: content_hash (e.g., `a1b2c3d4...png`)
- Supports: PNG, TIFF, JPEG, WebP
- Cleanup: Blob files deleted when physical delete is called for associated item

### Migration Strategy

When upgrading to new versions:
- Add new columns via `ALTER TABLE` (when possible)
- For schema-breaking changes, create new tables and migrate data
- Keep old schema in backup for rollback

## Data Integrity

### Deduplication
- Consecutive duplicates: If last item has same hash and created_at within 3 seconds → skip insert
- Global dedupe: Optional window (e.g., last 50 items) to avoid storing identical content

### Soft Delete
- `deleted_at_ms` is set instead of removing rows
- Query filters out deleted items by default (`WHERE deleted_at_ms IS NULL`)
- Physical delete can be called for permanent removal

### Retention
- When exceeding `retentionMaxItems`, delete oldest non-pinned items
- Pinned items are never automatically deleted

## Related Documentation
- [core-abi.md](core-abi.md) - Core API for data access
- [overview.md](overview.md) - Product overview
