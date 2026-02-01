package main

import (
    "crypto/sha256"
    "database/sql"
    "encoding/hex"
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

func sha256HexBytes(b []byte) string {
    h := sha256.Sum256(b)
    return hex.EncodeToString(h[:])
}

// normalizeBlobPaths converts any absolute blob_path values (from older builds)
// into paths relative to dataDir, when possible.
func normalizeBlobPaths(db *sql.DB, dataDir string) error {
    // Normalize once per open; this keeps the DB portable if the user moves the
    // shared directory (e.g. to iCloud/Dropbox).
    rows, err := db.Query(`SELECT id, blob_path FROM items WHERE blob_path IS NOT NULL AND blob_path != ''`)
    if err != nil {
        return err
    }
    defer rows.Close()

    type row struct {
        id   string
        path string
    }
    toFix := make([]row, 0, 64)

    for rows.Next() {
        var id, p string
        if err := rows.Scan(&id, &p); err != nil {
            return err
        }
        if !filepath.IsAbs(p) {
            continue
        }

        // Only rewrite paths that live under dataDir.
        cleanedDir := filepath.Clean(dataDir)
        cleanedP := filepath.Clean(p)

        // Ensure trailing separator semantics.
        prefix := cleanedDir
        if !strings.HasSuffix(prefix, string(filepath.Separator)) {
            prefix += string(filepath.Separator)
        }

        if cleanedP == cleanedDir || strings.HasPrefix(cleanedP, prefix) {
            rel, err := filepath.Rel(cleanedDir, cleanedP)
            if err != nil {
                continue
            }
            if rel == "." || strings.HasPrefix(rel, "..") {
                continue
            }
            toFix = append(toFix, row{id: id, path: rel})
        }
    }
    if err := rows.Err(); err != nil {
        return err
    }

    if len(toFix) == 0 {
        return nil
    }

    tx, err := db.Begin()
    if err != nil {
        return err
    }
    defer func() { _ = tx.Rollback() }()

    stmt, err := tx.Prepare(`UPDATE items SET blob_path=? WHERE id=?`)
    if err != nil {
        return err
    }
    defer stmt.Close()

    for _, r := range toFix {
        if _, err := stmt.Exec(r.path, r.id); err != nil {
            return err
        }
    }

    return tx.Commit()
}

func ensureBlobsDir(dataDir string) (string, error) {
    dir := filepath.Join(dataDir, "data", "blobs")
    if err := os.MkdirAll(dir, 0o755); err != nil {
        return "", fmt.Errorf("mkdir blobs dir: %w", err)
    }
    return dir, nil
}

// writeBlobFile writes a blob under <dataDir>/data/blobs and returns a *relative*
// path suitable for storing in SQLite (portable across configurable dataDir).
func writeBlobFile(dataDir, id, ext string, b []byte) (relPath string, nbytes int64, _ error) {
    _, err := ensureBlobsDir(dataDir)
    if err != nil {
        return "", 0, err
    }
    if ext == "" {
        ext = "bin"
    }
    name := id + "." + ext

    rel := filepath.Join("data", "blobs", name)
    abs := filepath.Join(dataDir, rel)

    if err := os.WriteFile(abs, b, 0o644); err != nil {
        return "", 0, fmt.Errorf("write blob: %w", err)
    }
    return rel, int64(len(b)), nil
}
