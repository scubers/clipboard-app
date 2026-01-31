package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"time"
	"unicode"
	"unsafe"

	"github.com/google/uuid"
)

const (
	ctOK            = 0
	ctErrInvalidArg = 2
	ctErrIO         = 3
	ctErrDB         = 4
	ctErrNotFound   = 5
)

type itemRow struct {
	ID          string  `json:"id"`
	CreatedAtMs int64   `json:"createdAtMs"`
	Type        string  `json:"type"`
	Summary     string  `json:"summary"`
	SourceApp   *string `json:"sourceApp"`
	Pinned      bool    `json:"pinned"`
}

func canonicalizeText(s string) string {
	// Normalize newlines to \n
	s = strings.ReplaceAll(s, "\r\n", "\n")
	s = strings.ReplaceAll(s, "\r", "\n")
	// Trim trailing whitespace, keep leading whitespace as-is.
	s = strings.TrimRightFunc(s, unicode.IsSpace)
	return s
}

func makeSummary(s string, maxChars int) string {
	// Whitespace normalize for summary: split and re-join with single spaces.
	fields := strings.Fields(s)
	n := len(fields)
	if n == 0 {
		return ""
	}
	norm := strings.Join(fields, " ")
	if len([]rune(norm)) <= maxChars {
		return norm
	}
	return string([]rune(norm)[:maxChars])
}

func sha256Hex(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}

func getDB(c *core) (*sql.DB, error) {
	if c.db == nil {
		return nil, fmt.Errorf("db not available")
	}
	return c.db, nil
}

func isRecentDuplicate(db *sql.DB, hash string, createdAtMs int64) (bool, error) {
	var lastHash string
	var lastCreated int64
	err := db.QueryRow(`SELECT content_hash, created_at_ms FROM items WHERE deleted_at_ms IS NULL ORDER BY created_at_ms DESC LIMIT 1`).Scan(&lastHash, &lastCreated)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if lastHash != hash {
		return false, nil
	}
	if createdAtMs-lastCreated <= 3000 {
		return true, nil
	}
	return false, nil
}

func enforceRetention(db *sql.DB, maxItems int) error {
	if maxItems <= 0 {
		return nil
	}
	// Count non-deleted
	var cnt int
	if err := db.QueryRow(`SELECT COUNT(1) FROM items WHERE deleted_at_ms IS NULL`).Scan(&cnt); err != nil {
		return err
	}
	if cnt <= maxItems {
		return nil
	}
	toDelete := cnt - maxItems
	// Delete oldest non-pinned items (soft delete)
	_, err := db.Exec(`UPDATE items SET deleted_at_ms=? WHERE id IN (
		SELECT id FROM items
		WHERE deleted_at_ms IS NULL AND pinned=0
		ORDER BY created_at_ms ASC
		LIMIT ?
	)`, time.Now().UnixMilli(), toDelete)
	return err
}

//export ct_items_add_text
func ct_items_add_text(corePtr *C.void, textUTF8 *C.char, sourceApp *C.char, createdAtMs C.longlong, outID **C.char) C.int {
	if corePtr == nil || textUTF8 == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	if outID != nil {
		*outID = nil
	}

	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}

	// Load settings (lightweight; cached in core)
	s := c.settings
	if s.PrivacyMode {
		return ctOK
	}

	text := canonicalizeText(C.GoString(textUTF8))
	if text == "" {
		// Ignore empty content
		return ctOK
	}

	created := int64(createdAtMs)
	hash := sha256Hex(text)

	db, err := getDB(c)
	if err != nil {
		setErr(err.Error())
		return ctErrDB
	}

	dup, err := isRecentDuplicate(db, hash, created)
	if err != nil {
		setErr("dedupe query: " + err.Error())
		return ctErrDB
	}
	if dup {
		return ctOK
	}

	id := uuid.NewString()
	summary := makeSummary(text, 120)
	var src *string
	if sourceApp != nil {
		v := C.GoString(sourceApp)
		if v != "" {
			src = &v
		}
	}

	_, err = db.Exec(`INSERT INTO items(id, created_at_ms, type, summary, text_content, content_hash, source_app, pinned, deleted_at_ms)
		VALUES(?, ?, 'text', ?, ?, ?, ?, 0, NULL)`, id, created, summary, text, hash, src)
	if err != nil {
		setErr("insert item: " + err.Error())
		return ctErrDB
	}

	if err := enforceRetention(db, s.RetentionMaxItems); err != nil {
		setErr("retention: " + err.Error())
		return ctErrDB
	}

	if outID != nil {
		*outID = C.CString(id)
	}
	return ctOK
}

//export ct_items_list_json
func ct_items_list_json(corePtr *C.void, limit C.int, offset C.int, includeDeleted C.int, outJSON **C.char) C.int {
	if corePtr == nil || outJSON == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	*outJSON = nil

	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	db, err := getDB(c)
	if err != nil {
		setErr(err.Error())
		return ctErrDB
	}

	l := int(limit)
	o := int(offset)
	if l <= 0 {
		l = 50
	}
	if l > 500 {
		l = 500
	}
	if o < 0 {
		o = 0
	}

	where := "WHERE 1=1"
	if includeDeleted == 0 {
		where += " AND deleted_at_ms IS NULL"
	}

	rows, err := db.Query(fmt.Sprintf(`SELECT id, created_at_ms, type, summary, source_app, pinned FROM items %s ORDER BY pinned DESC, created_at_ms DESC LIMIT ? OFFSET ?`, where), l, o)
	if err != nil {
		setErr("list query: " + err.Error())
		return ctErrDB
	}
	defer rows.Close()

	out := make([]itemRow, 0, l)
	for rows.Next() {
		var r itemRow
		var source sql.NullString
		var pinned int
		if err := rows.Scan(&r.ID, &r.CreatedAtMs, &r.Type, &r.Summary, &source, &pinned); err != nil {
			setErr("list scan: " + err.Error())
			return ctErrDB
		}
		if source.Valid {
			s := source.String
			r.SourceApp = &s
		}
		r.Pinned = pinned != 0
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		setErr("list rows: " + err.Error())
		return ctErrDB
	}

	b, err := json.Marshal(out)
	if err != nil {
		setErr("json marshal: " + err.Error())
		return ctErrIO
	}

	*outJSON = (*C.char)(C.CBytes(append(b, 0)))
	return ctOK
}

//export ct_items_get_text
func ct_items_get_text(corePtr *C.void, id *C.char, outText **C.char) C.int {
	if corePtr == nil || id == nil || outText == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	*outText = nil

	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	db, err := getDB(c)
	if err != nil {
		setErr(err.Error())
		return ctErrDB
	}

	var text string
	err = db.QueryRow(`SELECT text_content FROM items WHERE id=? AND deleted_at_ms IS NULL`, C.GoString(id)).Scan(&text)
	if err == sql.ErrNoRows {
		return ctErrNotFound
	}
	if err != nil {
		setErr("get_text: " + err.Error())
		return ctErrDB
	}

	*outText = C.CString(text)
	return ctOK
}

//export ct_settings_get_privacy_mode
func ct_settings_get_privacy_mode(corePtr *C.void, outEnabled *C.int) C.int {
	if corePtr == nil || outEnabled == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	if c.settings.PrivacyMode {
		*outEnabled = 1
	} else {
		*outEnabled = 0
	}
	return ctOK
}

//export ct_settings_set_privacy_mode
func ct_settings_set_privacy_mode(corePtr *C.void, enabled C.int) C.int {
	if corePtr == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	c.settings.PrivacyMode = enabled != 0
	if err := saveSettings(c.dataDir, c.settings); err != nil {
		setErr("save settings: " + err.Error())
		return 20
	}
	return ctOK
}

//export ct_settings_get_retention_max
func ct_settings_get_retention_max(corePtr *C.void, outMax *C.int) C.int {
	if corePtr == nil || outMax == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	*outMax = C.int(c.settings.RetentionMaxItems)
	return ctOK
}

//export ct_settings_set_retention_max
func ct_settings_set_retention_max(corePtr *C.void, maxItems C.int) C.int {
	if corePtr == nil {
		setErr("invalid arg")
		return ctErrInvalidArg
	}
	if maxItems <= 0 || maxItems > 100000 {
		setErr("retention max out of range")
		return ctErrInvalidArg
	}
	c, ok := getCore(corePtr)
	if !ok {
		setErr("invalid core handle")
		return ctErrInvalidArg
	}
	c.settings.RetentionMaxItems = int(maxItems)
	if err := saveSettings(c.dataDir, c.settings); err != nil {
		setErr("save settings: " + err.Error())
		return 20
	}
	return ctOK
}

// ensure unused imports are kept
var _ = unsafe.Pointer(nil)
