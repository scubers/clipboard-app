package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"strings"
)

// ct_items_search_json_ex extends search with includeDeleted support.
// We keep the original ct_items_search_json for backward compatibility.
//
//export ct_items_search_json_ex
func ct_items_search_json_ex(corePtr *C.void, queryUTF8 *C.char, limit C.int, offset C.int, includeDeleted C.int, outJSON **C.char) C.int {
	if corePtr == nil || outJSON == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	*outJSON = nil

	if queryUTF8 == nil {
		setErr("invalid arg: query")
		return ctErrInvalidArg
	}

	q := strings.TrimSpace(C.GoString(queryUTF8))
	if q == "" {
		// Empty query => behave like list.
		return ct_items_list_json(corePtr, limit, offset, includeDeleted, outJSON)
	}

	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	db, err := getDB(c)
	if err != nil {
		setErr(err.Error())
		return ctErrDB
	}

	l := int(limit)
	o := int(offset)
	if l <= 0 {
		l = 50
	}
	if l > 500 {
		l = 500
	}
	if o < 0 {
		o = 0
	}

	// Prefer FTS5 when available.
	if c.hasFTS5 {
		ftsq := ftsQueryFromUserInput(q)
		if ftsq != "" {
			where := "WHERE 1=1"
			if includeDeleted == 0 {
				where += " AND items.deleted_at_ms IS NULL"
			}
			// Include OCR hits for images via LIKE (Plan A).
			toks := strings.Fields(q)
			if len(toks) == 0 {
				toks = []string{q}
			}
			ocrWhere := make([]string, 0, len(toks))
			args := make([]any, 0, 1+len(toks)+2+1) // +1 for tag match
			for _, t := range toks {
				ocrWhere = append(ocrWhere, "items.ocr_text LIKE ?")
				args = append(args, "%"+t+"%")
			}

			baseWhere := "WHERE 1=1"
			if includeDeleted == 0 {
				baseWhere += " AND items.deleted_at_ms IS NULL"
			}

			tagPattern := "%" + q + "%"
			qsql := fmt.Sprintf(`WITH hits AS (
				SELECT items.id AS id, 0 AS ocrMatched
				FROM items
				JOIN items_fts ON items_fts.rowid = items.rowid
				%s AND items_fts MATCH ?
				UNION ALL
				SELECT items.id AS id, 1 AS ocrMatched
				FROM items
				%s
				AND items.type='image'
				AND items.ocr_status=1
				AND (%s)
				UNION ALL
				SELECT items.id AS id, 0 AS ocrMatched
				FROM items
				JOIN item_tags it ON it.item_id = items.id
				JOIN tags t ON t.id = it.tag_id
				%s AND t.name LIKE ?
			), dedup AS (
				SELECT id, MAX(ocrMatched) AS ocrMatched FROM hits GROUP BY id
			)
			SELECT items.id, items.created_at_ms, items.last_copied_at_ms, items.type, items.summary, items.source_app, items.pinned, dedup.ocrMatched
			FROM items
			JOIN dedup ON dedup.id = items.id
			ORDER BY items.pinned DESC, items.last_copied_at_ms DESC, items.created_at_ms DESC
			LIMIT ? OFFSET ?`, baseWhere, baseWhere, strings.Join(ocrWhere, " OR "), baseWhere)

			args = append([]any{ftsq}, args...)
			args = append(args, tagPattern, l, o)

			rows, err := db.Query(qsql, args...)
			if err == nil {
				defer rows.Close()
				return scanItemsToJSON(rows, l, outJSON)
			}
			// fall back to LIKE
		}
	}

	pattern := "%" + q + "%"

	where := "WHERE 1=1"
	if includeDeleted == 0 {
		where += " AND deleted_at_ms IS NULL"
	}

	// Include OCR hits for images via LIKE (Plan A).
	toks := strings.Fields(q)
	if len(toks) == 0 {
		toks = []string{q}
	}
	ocrWhere := make([]string, 0, len(toks))
	argsOCR := make([]any, 0, len(toks))
	for _, t := range toks {
		ocrWhere = append(ocrWhere, "ocr_text LIKE ?")
		argsOCR = append(argsOCR, "%"+t+"%")
	}

	// Also search for items with tags matching the query
	tagPattern := "%" + q + "%"

	itemWhere := "WHERE 1=1"
	if includeDeleted == 0 {
		itemWhere += " AND items.deleted_at_ms IS NULL"
	}

	qsql := fmt.Sprintf(`WITH hits AS (
		SELECT id, 0 AS ocrMatched
		FROM items
		%s AND (text_content LIKE ? OR summary LIKE ?)
		UNION ALL
		SELECT id, 1 AS ocrMatched
		FROM items
		%s
		AND type='image'
		AND ocr_status=1
		AND (%s)
		UNION ALL
		SELECT items.id AS id, 0 AS ocrMatched
		FROM items
		JOIN item_tags it ON it.item_id = items.id
		JOIN tags t ON t.id = it.tag_id
		%s AND t.name LIKE ?
	), dedup AS (
		SELECT id, MAX(ocrMatched) AS ocrMatched FROM hits GROUP BY id
	)
	SELECT items.id, items.created_at_ms, items.last_copied_at_ms, items.type, items.summary, items.source_app, items.pinned, dedup.ocrMatched
	FROM items
	JOIN dedup ON dedup.id = items.id
	ORDER BY items.pinned DESC, items.last_copied_at_ms DESC, items.created_at_ms DESC
	LIMIT ? OFFSET ?`, where, where, strings.Join(ocrWhere, " Or "), itemWhere)

	args := []any{pattern, pattern}
	args = append(args, argsOCR...)
	args = append(args, tagPattern, l, o)

	rows, err := db.Query(qsql, args...)
	if err != nil {
		setErr("search query: " + err.Error())
		return ctErrDB
	}
	defer rows.Close()
	return scanItemsToJSON(rows, l, outJSON)
}
