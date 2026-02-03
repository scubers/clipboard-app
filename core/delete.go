package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"database/sql"
	"os"
	"path/filepath"
	"strings"
)

// ct_items_delete_physical physically deletes a single item and its blob file if applicable.
// - Deletes the item row from SQLite
// - For image items, deletes the associated blob file from data/blobs/
// - Returns CT_OK on success, error code on failure
//
//export ct_items_delete_physical
func ct_items_delete_physical(corePtr *C.void, id *C.char) C.int {
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

	itemID := C.GoString(id)

	// Get blob_path for the item before deletion (for image cleanup)
	var blobPath sql.NullString
	err = db.QueryRow(`SELECT blob_path FROM items WHERE id=?`, itemID).Scan(&blobPath)
	if err == sql.ErrNoRows {
		return ctErrNotFound
	}
	if err != nil {
		setErr("query blob_path: " + err.Error())
		return ctErrDB
	}

	// Delete the database row
	res, err := db.Exec(`DELETE FROM items WHERE id=?`, itemID)
	if err != nil {
		setErr("delete item: " + err.Error())
		return ctErrDB
	}

	n, err := res.RowsAffected()
	if err != nil {
		setErr("rows affected: " + err.Error())
		return ctErrDB
	}
	if n == 0 {
		return ctErrNotFound
	}

	// Best-effort: remove blob file if exists
	if blobPath.Valid && blobPath.String != "" {
		pp := strings.TrimSpace(blobPath.String)
		if pp != "" {
			// Normalize to absolute path if needed
			if !filepath.IsAbs(pp) {
				pp = filepath.Join(c.dataDir, pp)
			}
			// Silently ignore file removal errors (already deleted from DB)
			_ = os.Remove(pp)
		}
	}

	return ctOK
}
