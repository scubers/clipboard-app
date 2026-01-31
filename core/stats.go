package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
)

type stats struct {
	TotalItems        int64 `json:"totalItems"`
	ActiveItems       int64 `json:"activeItems"`
	DeletedItems      int64 `json:"deletedItems"`
	PinnedActiveItems int64 `json:"pinnedActiveItems"`
}

//export ct_items_stats_json
func ct_items_stats_json(corePtr *C.void, outJSON **C.char) C.int {
	if corePtr == nil || outJSON == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	*outJSON = nil

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

	var st stats

	// total
	if err := db.QueryRow(`SELECT COUNT(1) FROM items`).Scan(&st.TotalItems); err != nil {
		setErr("stats total: " + err.Error())
		return ctErrDB
	}
	// active
	if err := db.QueryRow(`SELECT COUNT(1) FROM items WHERE deleted_at_ms IS NULL`).Scan(&st.ActiveItems); err != nil {
		setErr("stats active: " + err.Error())
		return ctErrDB
	}
	st.DeletedItems = st.TotalItems - st.ActiveItems
	// pinned active
	if err := db.QueryRow(`SELECT COUNT(1) FROM items WHERE deleted_at_ms IS NULL AND pinned=1`).Scan(&st.PinnedActiveItems); err != nil {
		setErr("stats pinned: " + err.Error())
		return ctErrDB
	}

	b, err := json.Marshal(st)
	if err != nil {
		setErr("stats json: " + err.Error())
		return ctErrIO
	}

	*outJSON = (*C.char)(C.CBytes(append(b, 0)))
	return ctOK
}
