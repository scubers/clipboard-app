package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ct_items_remove_history physically deletes rows and associated blob files.
//
// keepPinned:
// - 0 => remove everything (including pinned)
// - 1 => keep pinned rows
//
//export ct_items_remove_history
func ct_items_remove_history(corePtr *C.void, keepPinned C.int) C.int {
	if corePtr == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}

	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	if c.settings.PrivacyMode {
		// Privacy mode only stops capturing; it should not block explicit deletes.
	}

	db, err := getDB(c)
	if err != nil {
		setErr(err.Error())
		return ctErrDB
	}

	// 1) Collect blob paths to delete (best-effort, but we try hard).
	where := "1=1"
	if keepPinned != 0 {
		where += " AND pinned=0"
	}

	tx, err := db.Begin()
	if err != nil {
		setErr("begin tx: " + err.Error())
		return ctErrDB
	}
	defer func() { _ = tx.Rollback() }()

	rows, err := tx.Query(fmt.Sprintf(`SELECT blob_path FROM items WHERE %s AND blob_path IS NOT NULL AND blob_path != ''`, where))
	if err != nil {
		setErr("query blob_path: " + err.Error())
		return ctErrDB
	}
	var paths []string
	for rows.Next() {
		var p sql.NullString
		if err := rows.Scan(&p); err != nil {
			_ = rows.Close()
			setErr("scan blob_path: " + err.Error())
			return ctErrDB
		}
		if p.Valid {
			pp := strings.TrimSpace(p.String)
			if pp != "" {
				// Normalize to absolute path if needed.
				if !filepath.IsAbs(pp) {
					pp = filepath.Join(c.dataDir, pp)
				}
				paths = append(paths, pp)
			}
		}
	}
	if err := rows.Err(); err != nil {
		_ = rows.Close()
		setErr("rows blob_path: " + err.Error())
		return ctErrDB
	}
	_ = rows.Close()

	// 2) Physically delete DB rows.
	res, err := tx.Exec(fmt.Sprintf(`DELETE FROM items WHERE %s`, where))
	if err != nil {
		setErr("delete rows: " + err.Error())
		return ctErrDB
	}
	_, _ = res.RowsAffected()

	if err := tx.Commit(); err != nil {
		setErr("commit: " + err.Error())
		return ctErrDB
	}

	// 3) Remove blob files after DB commit (best-effort).
	var failed []string
	for _, p := range paths {
		if err := os.Remove(p); err != nil {
			if os.IsNotExist(err) {
				continue
			}
			failed = append(failed, p+": "+err.Error())
		}
	}
	if len(failed) > 0 {
		setErr("some blob files could not be removed: " + strings.Join(failed, " | "))
		return ctErrIO
	}

	return ctOK
}
