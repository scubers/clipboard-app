# SPEC — OCR Image Search (v1)

Status: **Approved (BB4F1273)**

## Goal
When searching from the main popover, images should be searchable by text recognized **inside the image** (OCR).

## Decisions (locked)
1. OCR engine: **macOS Vision** (local, on-device) ✅
2. Languages: **Chinese + English + Japanese** (zh + en + ja) ✅
3. v1 search integration: **Plan A** — merge OCR hits via `LIKE` (no FTS integration yet) ✅
4. OCR trigger strategy: **On-demand** ✅
5. OCR text max length: **16k characters** ✅
6. UI: show an **OCR match** indicator on image items ✅

---

## Data Model (SQLite)
Add columns to `items`:
- `ocr_text TEXT` — OCR plain text (UTF-8). Stored for `type='image'` only.
- `ocr_status INTEGER` — 0=unknown/pending, 1=done, 2=failed.
- `ocr_updated_at_ms INTEGER` — last time OCR text was produced.

Notes:
- `ocr_text` is truncated to maxLen=16384 characters.
- Keep existing ordering: `pinned DESC, last_copied_at_ms DESC, created_at_ms DESC`.

---

## Core ABI additions (Go dylib)
Expose a write API so the macOS app can persist OCR results:
- `ct_items_set_ocr_text(core, id, ocrText, status, updatedAtMs)`
  - updates `ocr_text`, `ocr_status`, `ocr_updated_at_ms`
  - for status=2 (failed), store empty text

Optional convenience API:
- `ct_items_get_ocr_status(core, id) -> (status, updatedAtMs)`

---

## OCR runtime (macOS)
Use Vision:
- `VNRecognizeTextRequest`
- recognitionLanguages: `zh-Hans`, `en-US`, `ja-JP` (exact values to confirm at implementation time)

Input:
- image file path resolved from blob (existing core API `getBlobPath`)

Output:
- concatenated recognized strings separated by newlines
- truncated to 16k chars

Failure handling:
- if image missing/unsupported/OCR errors → status=failed

---

## Trigger strategy (On-demand)
### When to run OCR
OCR runs only when needed:
1. During search, for image items that are candidates and do not have OCR done.
2. Optionally prioritize:
   - newest images first
   - currently visible search results first

### Candidate selection
During a search query `q`:
- If image rows already have `ocr_text` populated, include them via `ocr_text LIKE`.
- If not, run OCR for a limited batch (e.g. up to 3–10 images per query) and re-run the search after results are saved.

Concurrency:
- OCR concurrency = 1 (avoid CPU spikes)

---

## Search behavior
### Matching rules
- Text items: existing behavior unchanged.
- Image items:
  - match if `ocr_text` contains query tokens (`LIKE %token%`).

### v1 SQL shape
- Existing FTS/LIKE search returns base set.
- Add OCR clause for images:
  - `type='image' AND ocr_status=1 AND ocr_text LIKE ?`
- Merge results with de-dup by id.

---

## UI behavior
For image items in list:
- If result matched via OCR, show a subtle indicator:
  - e.g. `OCR` badge / `OCR match` label in the metadata line.

Implementation note:
- Add a boolean field in item JSON (preferred): `ocrMatched`.
  - Or infer in UI if the query matches ocr_text (not preferred due to perf and not having ocr_text in list payload).

---

## Privacy
- OCR runs locally on device.
- OCR text stored in the shared database (and thus may sync if user puts shared dir in a synced folder).

---

## Future (v2+)
- Integrate OCR text into FTS for speed and ranking.
- Background OCR job (idle-time) for recent images.
- OCR rerun button in Advanced.
