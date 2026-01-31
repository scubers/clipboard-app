package main

import (
	"database/sql"
	"fmt"
	"strings"
)

func migrateToV2(db *sql.DB) error {
	// Add FTS5 table + triggers if the SQLite build supports it.
	// If not supported, we keep running with LIKE fallback.

	stmts := []string{
		`CREATE VIRTUAL TABLE IF NOT EXISTS items_fts USING fts5(
			id,
			text_content,
			summary,
			content='items',
			content_rowid='rowid'
		);`,
		// Triggers to keep in sync
		`CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items BEGIN
			INSERT INTO items_fts(rowid, id, text_content, summary) VALUES (new.rowid, new.id, new.text_content, new.summary);
		END;`,
		`CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items BEGIN
			INSERT INTO items_fts(items_fts, rowid, id, text_content, summary) VALUES('delete', old.rowid, old.id, old.text_content, old.summary);
		END;`,
		`CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items BEGIN
			INSERT INTO items_fts(items_fts, rowid, id, text_content, summary) VALUES('delete', old.rowid, old.id, old.text_content, old.summary);
			INSERT INTO items_fts(rowid, id, text_content, summary) VALUES (new.rowid, new.id, new.text_content, new.summary);
		END;`,
		// Backfill existing content
		`INSERT INTO items_fts(rowid, id, text_content, summary)
			SELECT rowid, id, text_content, summary FROM items
			WHERE rowid NOT IN (SELECT rowid FROM items_fts);`,
	}

	for _, s := range stmts {
		if _, err := db.Exec(s); err != nil {
			// Detect common "no such module: fts5" case.
			msg := strings.ToLower(err.Error())
			if strings.Contains(msg, "no such module") && strings.Contains(msg, "fts5") {
				// Record and continue.
				_, _ = db.Exec(`INSERT OR REPLACE INTO meta(key,value) VALUES('fts5', '0')`)
				return nil
			}
			return fmt.Errorf("migrate v2 (fts5): %w", err)
		}
	}

	_, _ = db.Exec(`INSERT OR REPLACE INTO meta(key,value) VALUES('fts5', '1')`)
	return nil
}
