package main

// #include <stdlib.h>
import "C"
import (
	"encoding/json"
	"fmt"
	"time"
	"unsafe"

	"github.com/google/uuid"
)

// Tag represents a tag in the system
type Tag struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	CreatedAtMs int64  `json:"createdAtMs"`
	ColorHex    string `json:"colorHex"`
}

// TagWithCount represents a tag with usage count
type TagWithCount struct {
	Tag
	ItemCount int `json:"itemCount"`
}

// TagForItem represents a tag associated with an item (with color)
type TagForItem struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	ColorHex string `json:"colorHex"`
}

// Tag color palette - 16 distinct colors
var tagColorPalette = []string{
	"#E57373", "#C2185B", "#9B59B6", "#007AFF",
	"#32ADE6", "#4CD964", "#FF9500", "#FFCC00",
	"#FF6B6B", "#20B2AA", "#7FE5E8", "#AF52DE",
	"#FF695C", "#38BDF8", "#A78BFA", "#34D399",
}

// colorForTag returns a deterministic color for a tag name
func colorForTag(name string) string {
	hash := 0
	for _, c := range name {
		hash = (hash + int(c)) % 16
	}
	return tagColorPalette[hash]
}

// validateTagName checks if a tag name is valid
func validateTagName(name string) error {
	if len(name) == 0 {
		return fmt.Errorf("tag name cannot be empty")
	}
	if len(name) > 50 {
		return fmt.Errorf("tag name exceeds 50 characters")
	}
	for _, c := range name {
		if c == ',' {
			return fmt.Errorf("tag name cannot contain commas")
		}
	}
	return nil
}

// ct_items_add_tag adds a tag to an item, creating the tag if it doesn't exist
//
//export ct_items_add_tag
func ct_items_add_tag(core unsafe.Pointer, itemIDC *C.char, tagNameC *C.char, colorHexC *C.char) C.int {
	itemID := C.GoString(itemIDC)
	tagName := C.GoString(tagNameC)
	colorHex := C.GoString(colorHexC)

	if itemID == "" || tagName == "" {
		setErr("item_id and tag_name are required")
		return -1
	}

	// Validate tag name
	if err := validateTagName(tagName); err != nil {
		setErr(err.Error())
		return -1
	}

	c, ok := getCore((*C.void)(core))
	if !ok {
		setErr("core not opened")
		return -1
	}

	now := time.Now().UnixMilli()

	// Start transaction
	tx, err := c.db.Begin()
	if err != nil {
		setErr(fmt.Sprintf("begin transaction: %v", err))
		return -1
	}
	defer tx.Rollback()

	// Try to find existing tag
	var tagID string
	err = tx.QueryRow(`SELECT id FROM tags WHERE name = ?`, tagName).Scan(&tagID)
	if err != nil && err.Error() != "sql: no rows in result set" {
		setErr(fmt.Sprintf("query tag: %v", err))
		return -1
	}

	// Create tag if it doesn't exist
	if tagID == "" {
		tagID = uuid.Must(uuid.NewRandom()).String()
		if colorHex == "" {
			colorHex = colorForTag(tagName)
		}
		_, err = tx.Exec(
			`INSERT INTO tags (id, name, created_at_ms, color_hex) VALUES (?, ?, ?, ?)`,
			tagID, tagName, now, colorHex,
		)
		if err != nil {
			setErr(fmt.Sprintf("create tag: %v", err))
			return -1
		}
	}

	// Check if association already exists
	var existing int
	err = tx.QueryRow(
		`SELECT 1 FROM item_tags WHERE item_id = ? AND tag_id = ?`,
		itemID, tagID,
	).Scan(&existing)
	if err == nil {
		// Already exists, return success
		return 0
	}

	// Create item-tag association
	_, err = tx.Exec(
		`INSERT INTO item_tags (item_id, tag_id, created_at_ms) VALUES (?, ?, ?)`,
		itemID, tagID, now,
	)
	if err != nil {
		setErr(fmt.Sprintf("create item_tag: %v", err))
		return -1
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		setErr(fmt.Sprintf("commit: %v", err))
		return -1
	}

	return 0
}

// ct_items_remove_tag removes a tag from an item
//
//export ct_items_remove_tag
func ct_items_remove_tag(core unsafe.Pointer, itemIDC *C.char, tagIDC *C.char) C.int {
	itemID := C.GoString(itemIDC)
	tagID := C.GoString(tagIDC)

	if itemID == "" || tagID == "" {
		setErr("item_id and tag_id are required")
		return -1
	}

	c, ok := getCore((*C.void)(core))
	if !ok {
		setErr("core not opened")
		return -1
	}

	_, err := c.db.Exec(
		`DELETE FROM item_tags WHERE item_id = ? AND tag_id = ?`,
		itemID, tagID,
	)
	if err != nil {
		setErr(fmt.Sprintf("remove tag: %v", err))
		return -1
	}

	return 0
}

// ct_items_get_tags gets all tags for an item
//
//export ct_items_get_tags
func ct_items_get_tags(core unsafe.Pointer, itemIDC *C.char, outJSON **C.char) C.int {
	itemID := C.GoString(itemIDC)

	if itemID == "" {
		setErr("item_id is required")
		return -1
	}

	c, ok := getCore((*C.void)(core))
	if !ok {
		setErr("core not opened")
		return -1
	}

	rows, err := c.db.Query(
		`SELECT t.id, t.name, t.color_hex 
		 FROM tags t 
		 JOIN item_tags it ON it.tag_id = t.id 
		 WHERE it.item_id = ? 
		 ORDER BY t.name`,
		itemID,
	)
	if err != nil {
		setErr(fmt.Sprintf("query tags: %v", err))
		return -1
	}
	defer rows.Close()

	tags := make([]TagForItem, 0)
	for rows.Next() {
		var tag TagForItem
		var colorHex string
		err := rows.Scan(&tag.ID, &tag.Name, &colorHex)
		if err != nil {
			continue
		}
		if colorHex != "" {
			tag.ColorHex = colorHex
		} else {
			tag.ColorHex = colorForTag(tag.Name)
		}
		tags = append(tags, tag)
	}

	data, err := json.Marshal(tags)
	if err != nil {
		setErr(fmt.Sprintf("marshal: %v", err))
		return -1
	}

	*outJSON = (*C.char)(C.CString(string(data)))
	return 0
}

// ct_tags_list lists all tags in the system with usage count
//
//export ct_tags_list
func ct_tags_list(core unsafe.Pointer, outJSON **C.char) C.int {
	c, ok := getCore((*C.void)(core))
	if !ok {
		setErr("core not opened")
		return -1
	}

	rows, err := c.db.Query(
		`SELECT t.id, t.name, t.created_at_ms, t.color_hex, COUNT(it.item_id) as item_count
		 FROM tags t
		 LEFT JOIN item_tags it ON it.tag_id = t.id
		 GROUP BY t.id, t.name, t.created_at_ms, t.color_hex
		 ORDER BY item_count DESC, t.name`,
	)
	if err != nil {
		setErr(fmt.Sprintf("query tags: %v", err))
		return -1
	}
	defer rows.Close()

	tags := make([]TagWithCount, 0)
	for rows.Next() {
		var tag TagWithCount
		var colorHex *string
		err := rows.Scan(&tag.ID, &tag.Name, &tag.CreatedAtMs, &colorHex, &tag.ItemCount)
		if err != nil {
			continue
		}
		if colorHex != nil && *colorHex != "" {
			tag.ColorHex = *colorHex
		} else {
			tag.ColorHex = colorForTag(tag.Name)
		}
		tags = append(tags, tag)
	}

	data, err := json.Marshal(tags)
	if err != nil {
		setErr(fmt.Sprintf("marshal: %v", err))
		return -1
	}

	*outJSON = (*C.char)(C.CString(string(data)))
	return 0
}

// ct_tags_rename renames a tag
//
//export ct_tags_rename
func ct_tags_rename(core unsafe.Pointer, tagIDC *C.char, newNameC *C.char) C.int {
	tagID := C.GoString(tagIDC)
	newName := C.GoString(newNameC)

	if tagID == "" || newName == "" {
		setErr("tag_id and new_name are required")
		return -1
	}

	// Validate new name
	if err := validateTagName(newName); err != nil {
		setErr(err.Error())
		return -1
	}

	c, ok := getCore((*C.void)(core))
	if !ok {
		setErr("core not opened")
		return -1
	}

	// Check if new name already exists
	var existingID string
	err := c.db.QueryRow(`SELECT id FROM tags WHERE name = ? AND id != ?`, newName, tagID).Scan(&existingID)
	if err == nil {
		setErr(fmt.Sprintf("tag name '%s' already exists", newName))
		return -1
	}

	// Update tag name
	_, err = c.db.Exec(`UPDATE tags SET name = ? WHERE id = ?`, newName, tagID)
	if err != nil {
		setErr(fmt.Sprintf("rename tag: %v", err))
		return -1
	}

	return 0
}

// ct_tags_delete deletes a tag and all its associations
//
//export ct_tags_delete
func ct_tags_delete(core unsafe.Pointer, tagIDC *C.char) C.int {
	tagID := C.GoString(tagIDC)

	if tagID == "" {
		setErr("tag_id is required")
		return -1
	}

	c, ok := getCore((*C.void)(core))
	if !ok {
		setErr("core not opened")
		return -1
	}

	// Delete tag (cascade will handle item_tags)
	_, err := c.db.Exec(`DELETE FROM tags WHERE id = ?`, tagID)
	if err != nil {
		setErr(fmt.Sprintf("delete tag: %v", err))
		return -1
	}

	return 0
}
