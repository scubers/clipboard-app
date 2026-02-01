package main

import (
	"database/sql"
	"fmt"
)

func migrateToV5(db *sql.DB) error {
	// OCR support for image items.
	stmts := []string{
		`ALTER TABLE items ADD COLUMN ocr_text TEXT;`,
		`ALTER TABLE items ADD COLUMN ocr_status INTEGER;`,
		`ALTER TABLE items ADD COLUMN ocr_updated_at_ms INTEGER;`,
		// Backfill defaults
		`UPDATE items SET ocr_status=0 WHERE ocr_status IS NULL;`,
		`CREATE INDEX IF NOT EXISTS idx_items_ocr_status ON items(ocr_status);`,
	}

	for _, s := range stmts {
		if _, err := db.Exec(s); err != nil {
			if isSQLiteDuplicateColumnErr(err) {
				continue
			}
			return fmt.Errorf("migrate v5: %w", err)
		}
	}
	return nil
}
