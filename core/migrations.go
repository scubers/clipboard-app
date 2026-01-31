package main

import (
	"database/sql"
	"fmt"
)

const schemaVersion = 2

func ensureSchema(db *sql.DB) error {
	// Create meta table
	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS meta (
		key TEXT PRIMARY KEY,
		value TEXT NOT NULL
	);`); err != nil {
		return fmt.Errorf("create meta: %w", err)
	}

	// Read current version
	var vStr string
	err := db.QueryRow(`SELECT value FROM meta WHERE key='schema_version'`).Scan(&vStr)
	cur := 0
	if err == sql.ErrNoRows {
		cur = 0
	} else if err != nil {
		return fmt.Errorf("read schema_version: %w", err)
	} else {
		_, _ = fmt.Sscanf(vStr, "%d", &cur)
	}

	if cur > schemaVersion {
		return fmt.Errorf("db schema version %d is newer than supported %d", cur, schemaVersion)
	}

	if cur < 1 {
		if err := migrateToV1(db); err != nil {
			return err
		}
		cur = 1
		if _, err := db.Exec(`INSERT OR REPLACE INTO meta(key,value) VALUES('schema_version', '1')`); err != nil {
			return fmt.Errorf("set schema_version v1: %w", err)
		}
	}

	if cur < 2 {
		if err := migrateToV2(db); err != nil {
			return err
		}
		cur = 2
		if _, err := db.Exec(`INSERT OR REPLACE INTO meta(key,value) VALUES('schema_version', '2')`); err != nil {
			return fmt.Errorf("set schema_version v2: %w", err)
		}
	}

	return nil
}

func migrateToV1(db *sql.DB) error {
	// Pragmas
	if _, err := db.Exec(`PRAGMA journal_mode=WAL;`); err != nil {
		return fmt.Errorf("pragma wal: %w", err)
	}
	if _, err := db.Exec(`PRAGMA synchronous=NORMAL;`); err != nil {
		return fmt.Errorf("pragma sync: %w", err)
	}

	// Items table (text-only)
	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS items (
		id TEXT PRIMARY KEY,
		created_at_ms INTEGER NOT NULL,
		type TEXT NOT NULL,
		summary TEXT NOT NULL,
		text_content TEXT NOT NULL,
		content_hash TEXT NOT NULL,
		source_app TEXT,
		pinned INTEGER NOT NULL DEFAULT 0,
		deleted_at_ms INTEGER
	);

	CREATE INDEX IF NOT EXISTS idx_items_created_at ON items(created_at_ms DESC);
	CREATE INDEX IF NOT EXISTS idx_items_deleted ON items(deleted_at_ms);
	CREATE INDEX IF NOT EXISTS idx_items_pinned ON items(pinned DESC, created_at_ms DESC);
	CREATE INDEX IF NOT EXISTS idx_items_hash ON items(content_hash);
	`); err != nil {
		return fmt.Errorf("create items: %w", err)
	}

	return nil
}
