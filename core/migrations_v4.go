package main

import (
	"database/sql"
	"fmt"
)

func migrateToV4(db *sql.DB) error {
	// Track when an item was last seen in the system clipboard.
	// We keep it separate from created_at_ms so repeated copies don't create duplicates.
	stmts := []string{
		`ALTER TABLE items ADD COLUMN last_copied_at_ms INTEGER;`,
		// Backfill existing rows.
		`UPDATE items SET last_copied_at_ms = created_at_ms WHERE last_copied_at_ms IS NULL;`,
		`CREATE INDEX IF NOT EXISTS idx_items_last_copied ON items(last_copied_at_ms DESC);`,
	}

	for _, s := range stmts {
		if _, err := db.Exec(s); err != nil {
			if isSQLiteDuplicateColumnErr(err) {
				continue
			}
			return fmt.Errorf("migrate v4: %w", err)
		}
	}
	return nil
}
