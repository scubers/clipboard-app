package main

import (
    "database/sql"
    "fmt"
)

func migrateToV3(db *sql.DB) error {
    // Add optional image/blob columns. Existing rows remain valid.
    stmts := []string{
        `ALTER TABLE items ADD COLUMN blob_path TEXT;`,
        `ALTER TABLE items ADD COLUMN mime TEXT;`,
        `ALTER TABLE items ADD COLUMN bytes INTEGER;`,
        `ALTER TABLE items ADD COLUMN width INTEGER;`,
        `ALTER TABLE items ADD COLUMN height INTEGER;`,
        // Helpful index for blobs
        `CREATE INDEX IF NOT EXISTS idx_items_type_created_at ON items(type, created_at_ms DESC);`,
    }

    for _, s := range stmts {
        if _, err := db.Exec(s); err != nil {
            // SQLite returns "duplicate column name" if already applied.
            // We keep migrations idempotent.
            if isSQLiteDuplicateColumnErr(err) {
                continue
            }
            // Index creation is idempotent anyway.
            return fmt.Errorf("migrate v3: %w", err)
        }
    }

    return nil
}
