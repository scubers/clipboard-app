package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
)

type integrityResult struct {
	OK      bool   `json:"ok"`
	Message string `json:"message"`
}

//export ct_db_integrity_check_json
func ct_db_integrity_check_json(corePtr *C.void, outJSON **C.char) C.int {
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

	var msg string
	// Returns single row with 'ok' or details.
	if err := db.QueryRow(`PRAGMA integrity_check;`).Scan(&msg); err != nil {
		setErr("integrity_check: " + err.Error())
		return ctErrDB
	}

	res := integrityResult{OK: msg == "ok", Message: msg}
	b, err := json.Marshal(res)
	if err != nil {
		setErr("integrity json: " + err.Error())
		return ctErrIO
	}
	*outJSON = (*C.char)(C.CBytes(append(b, 0)))
	return ctOK
}
