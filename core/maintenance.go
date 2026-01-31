package main

/*
#include <stdlib.h>
*/
import "C"

import "time"

// ct_items_clear_all soft-deletes items in bulk.
//
// keepPinned:
// - 0 => delete everything (including pinned)
// - 1 => delete only non-pinned items
//
//export ct_items_clear_all
func ct_items_clear_all(corePtr *C.void, keepPinned C.int, deletedAtMs C.longlong) C.int {
	if corePtr == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
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

	ms := int64(deletedAtMs)
	if ms <= 0 {
		ms = time.Now().UnixMilli()
	}

	if keepPinned != 0 {
		_, err = db.Exec(`UPDATE items SET deleted_at_ms=? WHERE deleted_at_ms IS NULL AND pinned=0`, ms)
	} else {
		_, err = db.Exec(`UPDATE items SET deleted_at_ms=? WHERE deleted_at_ms IS NULL`, ms)
	}
	if err != nil {
		setErr("clear_all: " + err.Error())
		return ctErrDB
	}

	return ctOK
}
