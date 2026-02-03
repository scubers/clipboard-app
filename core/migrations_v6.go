package main

import (
	"database/sql"
	"fmt"
)

func migrateToV6(db *sql.DB) error {
	// Tags support for organizing clipboard items.
	stmts := []string{
		// Tags table
		`CREATE TABLE IF NOT EXISTS tags (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL UNIQUE,
			created_at_ms INTEGER NOT NULL,
			color_hex TEXT
		);`,
		// Junction table for item-tag associations
		`CREATE TABLE IF NOT EXISTS item_tags (
			item_id TEXT NOT NULL,
			tag_id TEXT NOT NULL,
			created_at_ms INTEGER NOT NULL,
			PRIMARY KEY (item_id, tag_id),
			FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
			FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
		);`,
		// Indexes for tags
		`CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);`,
		`CREATE INDEX IF NOT EXISTS idx_item_tags_item ON item_tags(item_id);`,
		`CREATE INDEX IF NOT EXISTS idx_item_tags_tag ON item_tags(tag_id);`,
	}

	for _, s := range stmts {
		if _, err := db.Exec(s); err != nil {
			return fmt.Errorf("migrate v6: %w", err)
		}
	}
	return nil
}
