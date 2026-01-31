package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"database/sql"
	"encoding/json"
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

	// LIKE fallback search (case-insensitive)
	// We search only non-deleted items. Order: pinned desc, created_at desc.
	// Use a LIKE fallback search.
	// NOTE: SQLite ESCAPE is finicky across drivers/builds; we avoid ESCAPE in V1.
	// This means searching for literal '%' or '_' is not supported for now.
	pattern := "%" + q + "%"

	rows, err := db.Query(`SELECT id, created_at_ms, type, summary, source_app, pinned
		FROM items
		WHERE deleted_at_ms IS NULL
		AND (text_content LIKE ? OR summary LIKE ?)
		ORDER BY pinned DESC, created_at_ms DESC
		LIMIT ? OFFSET ?`, pattern, pattern, l, o)
	if err != nil {
		setErr("search query: " + err.Error())
		return ctErrDB
	}
	defer rows.Close()

	out := make([]itemRow, 0, l)
	for rows.Next() {
		var r itemRow
		var source sql.NullString
		var pinned int
		if err := rows.Scan(&r.ID, &r.CreatedAtMs, &r.Type, &r.Summary, &source, &pinned); err != nil {
			setErr("search scan: " + err.Error())
			return ctErrDB
		}
		if source.Valid {
			s := source.String
			r.SourceApp = &s
		}
		r.Pinned = pinned != 0
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		setErr("search rows: " + err.Error())
		return ctErrDB
	}

	b, err := json.Marshal(out)
	if err != nil {
		setErr("json marshal: " + err.Error())
		return ctErrIO
	}

	*outJSON = (*C.char)(C.CBytes(append(b, 0)))
	return ctOK
}

var _ = fmt.Sprintf
