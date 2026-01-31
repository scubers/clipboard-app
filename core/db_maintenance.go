package main

/*
#include <stdlib.h>
*/
import "C"

//export ct_db_vacuum
func ct_db_vacuum(corePtr *C.void) C.int {
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

	if _, err := db.Exec(`VACUUM;`); err != nil {
		setErr("vacuum: " + err.Error())
		return ctErrDB
	}
	return ctOK
}

//export ct_db_optimize
func ct_db_optimize(corePtr *C.void) C.int {
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

	// SQLite PRAGMA optimize is available in modern SQLite builds.
	// If unavailable, it will error; we treat that as CT_ERR_DB for now.
	if _, err := db.Exec(`PRAGMA optimize;`); err != nil {
		setErr("optimize: " + err.Error())
		return ctErrDB
	}
	return ctOK
}
