package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"database/sql"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

//export ct_export_to_dir
func ct_export_to_dir(corePtr *C.void, destDir *C.char) C.int {
	if corePtr == nil || destDir == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	dd := C.GoString(destDir)
	if dd == "" || !filepath.IsAbs(dd) {
		setErr("dest_dir must be absolute")
		return ctErrInvalidArg
	}

	// Ensure destination structure.
	if err := os.MkdirAll(filepath.Join(dd, "config"), 0o755); err != nil {
		setErr("mkdir dest config: " + err.Error())
		return ctErrIO
	}
	if err := os.MkdirAll(filepath.Join(dd, "data"), 0o755); err != nil {
		setErr("mkdir dest data: " + err.Error())
		return ctErrIO
	}

	// Flush WAL to make a consistent sqlite file.
	if c.db != nil {
		_, _ = c.db.Exec(`PRAGMA wal_checkpoint(FULL);`)
		_, _ = c.db.Exec(`PRAGMA optimize;`)
	}

	srcSettings := filepath.Join(c.dataDir, "config", "settings.json")
	srcDB := filepath.Join(c.dataDir, "data", "clipboard.sqlite")

	dstSettings := filepath.Join(dd, "config", "settings.json")
	dstDB := filepath.Join(dd, "data", "clipboard.sqlite")

	// Copy files (best-effort: if settings missing, we still export db)
	if err := copyFileIfExists(srcSettings, dstSettings); err != nil {
		setErr("export settings: " + err.Error())
		return ctErrIO
	}
	if err := copyFile(srcDB, dstDB); err != nil {
		setErr("export db: " + err.Error())
		return ctErrIO
	}

	// Write a small manifest.
	manifest := filepath.Join(dd, "manifest.txt")
	_ = os.WriteFile(manifest, []byte("ClipboardTool export\nversion=1\ncreated_at_ms="+fmt.Sprintf("%d", time.Now().UnixMilli())+"\n"), 0o644)

	return ctOK
}

//export ct_import_from_dir
func ct_import_from_dir(corePtr *C.void, srcDir *C.char, keepBackup C.int) C.int {
	if corePtr == nil || srcDir == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	sd := C.GoString(srcDir)
	if sd == "" || !filepath.IsAbs(sd) {
		setErr("src_dir must be absolute")
		return ctErrInvalidArg
	}

	srcSettings := filepath.Join(sd, "config", "settings.json")
	srcDB := filepath.Join(sd, "data", "clipboard.sqlite")

	// Validate source exists.
	if _, err := os.Stat(srcDB); err != nil {
		setErr("src db missing: " + err.Error())
		return ctErrIO
	}

	// Close current db before swapping.
	if c.db != nil {
		_ = c.db.Close()
		c.db = nil
	}

	// Backup current data (optional) by renaming.
	backupSuffix := fmt.Sprintf("backup-%d", time.Now().UnixMilli())
	if keepBackup != 0 {
		// Rename current db/settings if they exist.
		_ = renameIfExists(filepath.Join(c.dataDir, "data", "clipboard.sqlite"), filepath.Join(c.dataDir, "data", "clipboard.sqlite."+backupSuffix))
		_ = renameIfExists(filepath.Join(c.dataDir, "config", "settings.json"), filepath.Join(c.dataDir, "config", "settings.json."+backupSuffix))
	} else {
		// Remove existing files to avoid mixing.
		_ = os.Remove(filepath.Join(c.dataDir, "data", "clipboard.sqlite"))
		_ = os.Remove(filepath.Join(c.dataDir, "config", "settings.json"))
	}

	// Ensure dirs
	_ = os.MkdirAll(filepath.Join(c.dataDir, "config"), 0o755)
	_ = os.MkdirAll(filepath.Join(c.dataDir, "data"), 0o755)

	// Copy in
	if err := copyFile(srcDB, filepath.Join(c.dataDir, "data", "clipboard.sqlite")); err != nil {
		setErr("import db: " + err.Error())
		return ctErrIO
	}
	// settings is optional; if absent we'll recreate defaults
	if err := copyFileIfExists(srcSettings, filepath.Join(c.dataDir, "config", "settings.json")); err != nil {
		setErr("import settings: " + err.Error())
		return ctErrIO
	}

	// Reopen db and reload settings
	db, err := openDB(c.dataDir)
	if err != nil {
		setErr("reopen db: " + err.Error())
		return ctErrDB
	}
	s, err := loadSettings(c.dataDir)
	if err != nil {
		_ = db.Close()
		setErr("reload settings: " + err.Error())
		return 20
	}
	c.db = db
	c.settings = s
	c.settingsP = settingsPath(c.dataDir)

	return ctOK
}

func copyFileIfExists(src, dst string) error {
	if _, err := os.Stat(src); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	return copyFile(src, dst)
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}

	tmp := dst + ".tmp"
	out, err := os.Create(tmp)
	if err != nil {
		return err
	}

	_, copyErr := io.Copy(out, in)
	closeErr := out.Close()
	if copyErr != nil {
		_ = os.Remove(tmp)
		return copyErr
	}
	if closeErr != nil {
		_ = os.Remove(tmp)
		return closeErr
	}
	return os.Rename(tmp, dst)
}

func renameIfExists(src, dst string) error {
	if _, err := os.Stat(src); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	return os.Rename(src, dst)
}

var _ = sql.ErrNoRows
