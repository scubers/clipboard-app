package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"database/sql"
	"encoding/json"
)

func scanItemsToJSON(rows *sql.Rows, capHint int, outJSON **C.char) C.int {
	out := make([]itemRow, 0, capHint)
	for rows.Next() {
		var r itemRow
		var source sql.NullString
		var pinned int
		var ocrMatchedInt sql.NullInt64
		if err := rows.Scan(&r.ID, &r.CreatedAtMs, &r.LastCopiedAtMs, &r.Type, &r.Summary, &source, &pinned, &ocrMatchedInt); err != nil {
			setErr("scan: " + err.Error())
			return ctErrDB
		}
		if source.Valid {
			s := source.String
			r.SourceApp = &s
		}
		r.Pinned = pinned != 0
		if ocrMatchedInt.Valid {
			r.OCRMatched = ocrMatchedInt.Int64 != 0
		}
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		setErr("rows: " + err.Error())
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
