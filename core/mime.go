package main

import "strings"

func extFromMime(mime string) string {
    m := strings.ToLower(strings.TrimSpace(mime))
    switch m {
    case "image/png":
        return "png"
    case "image/jpeg", "image/jpg":
        return "jpg"
    case "image/tiff", "image/tif":
        return "tiff"
    case "image/webp":
        return "webp"
    default:
        return "bin"
    }
}
