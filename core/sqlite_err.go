package main

import "strings"

func isSQLiteDuplicateColumnErr(err error) bool {
    if err == nil {
        return false
    }
    msg := strings.ToLower(err.Error())
    return strings.Contains(msg, "duplicate column name")
}
