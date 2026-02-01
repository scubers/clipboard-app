package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"strings"
)

//export ct_items_search_json
func ct_items_search_json(corePtr *C.void, queryUTF8 *C.char, limit C.int, offset C.int, outJSON **C.char) C.int {
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
		return ct_items_list_json(corePtr, limit, offset, 0, outJSON)
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
			rows, err := db.Query(`SELECT items.id, items.created_at_ms, items.last_copied_at_ms, items.type, items.summary, items.source_app, items.pinned
				FROM items
				JOIN items_fts ON items_fts.rowid = items.rowid
				WHERE items.deleted_at_ms IS NULL
				AND items_fts MATCH ?
				ORDER BY items.pinned DESC, items.last_copied_at_ms DESC, items.created_at_ms DESC
				LIMIT ? OFFSET ?`, ftsq, l, o)
			if err == nil {
				defer rows.Close()
				return scanItemsToJSON(rows, l, outJSON)
			}
			// If FTS errors for some query, fall back to LIKE.
		}
	}

	// LIKE fallback.
	// NOTE: literal searching for '%' or '_' is not supported here.
	pattern := "%" + q + "%"

	rows, err := db.Query(`SELECT id, created_at_ms, last_copied_at_ms, type, summary, source_app, pinned
		FROM items
		WHERE deleted_at_ms IS NULL
		AND (text_content LIKE ? OR summary LIKE ?)
		ORDER BY pinned DESC, last_copied_at_ms DESC, created_at_ms DESC
		LIMIT ? OFFSET ?`, pattern, pattern, l, o)
	if err != nil {
		setErr("search query: " + err.Error())
		return ctErrDB
	}
	defer rows.Close()
	return scanItemsToJSON(rows, l, outJSON)
}

var _ = fmt.Sprintf
