package main

import (
	"database/sql"
	"fmt"
	"strings"
)

// detectFTS5 checks if items_fts exists.
func detectFTS5(db *sql.DB) (bool, error) {
	var name string
	err := db.QueryRow(`SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name='items_fts'`).Scan(&name)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return name == "items_fts", nil
}

func ftsQueryFromUserInput(q string) string {
	// Make a safe-ish MATCH query:
	// - split on whitespace
	// - prefix-match each token with *
	// - join with AND
	// Note: FTS5 query syntax is richer; this keeps UX simple.
	fields := strings.Fields(q)
	if len(fields) == 0 {
		return ""
	}
	out := make([]string, 0, len(fields))
	for _, tok := range fields {
		// Escape double quotes by doubling them.
		tok = strings.ReplaceAll(tok, "\"", "\"\"")
		out = append(out, fmt.Sprintf("\"%s\"*", tok))
	}
	return strings.Join(out, " AND ")
}
