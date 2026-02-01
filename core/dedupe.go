package main

import "database/sql"

// findExistingByHash returns the most recently copied row id for a given type+hash.
// It searches across both active and deleted rows (so we can revive).
func findExistingByHash(db *sql.DB, typ, hash string) (string, bool, error) {
	var id string
	err := db.QueryRow(`SELECT id FROM items WHERE type=? AND content_hash=? ORDER BY last_copied_at_ms DESC LIMIT 1`, typ, hash).Scan(&id)
	if err == sql.ErrNoRows {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return id, true, nil
}
