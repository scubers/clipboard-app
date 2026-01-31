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
			rows, err := db.Query(fmt.Sprintf(`SELECT items.id, items.created_at_ms, items.type, items.summary, items.source_app, items.pinned
				FROM items
				JOIN items_fts ON items_fts.rowid = items.rowid
				%s
				AND items_fts MATCH ?
				ORDER BY items.pinned DESC, items.created_at_ms DESC
				LIMIT ? OFFSET ?`, where), ftsq, l, o)
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
	where += " AND (text_content LIKE ? OR summary LIKE ?)"

	rows, err := db.Query(fmt.Sprintf(`SELECT id, created_at_ms, type, summary, source_app, pinned
		FROM items
		%s
		ORDER BY pinned DESC, created_at_ms DESC
		LIMIT ? OFFSET ?`, where), pattern, pattern, l, o)
	if err != nil {
		setErr("search query: " + err.Error())
		return ctErrDB
	}
	defer rows.Close()
	return scanItemsToJSON(rows, l, outJSON)
}
