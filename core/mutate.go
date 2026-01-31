package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"database/sql"
	"time"
)

//export ct_items_set_pinned
func ct_items_set_pinned(corePtr *C.void, id *C.char, pinned C.int) C.int {
	if corePtr == nil || id == nil {
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

	res, err := db.Exec(`UPDATE items SET pinned=? WHERE id=? AND deleted_at_ms IS NULL`, boolToInt(pinned != 0), C.GoString(id))
	if err != nil {
		setErr("set_pinned: " + err.Error())
		return ctErrDB
	}
	n, err := res.RowsAffected()
	if err != nil {
		setErr("set_pinned rows: " + err.Error())
		return ctErrDB
	}
	if n == 0 {
		return ctErrNotFound
	}
	return ctOK
}

//export ct_items_soft_delete
func ct_items_soft_delete(corePtr *C.void, id *C.char, deletedAtMs C.longlong) C.int {
	if corePtr == nil || id == nil {
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

	res, err := db.Exec(`UPDATE items SET deleted_at_ms=? WHERE id=? AND deleted_at_ms IS NULL`, ms, C.GoString(id))
	if err != nil {
		setErr("soft_delete: " + err.Error())
		return ctErrDB
	}
	n, err := res.RowsAffected()
	if err != nil {
		setErr("soft_delete rows: " + err.Error())
		return ctErrDB
	}
	if n == 0 {
		return ctErrNotFound
	}
	return ctOK
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

var _ = sql.ErrNoRows
