package main

import (
    "bytes"
    "image"
    "image/jpeg"
    "image/png"
    _ "golang.org/x/image/tiff"
    _ "golang.org/x/image/webp"
)

type imageMeta struct {
    width  int
    height int
}

func sniffImageMeta(mime string, b []byte) (imageMeta, bool) {
    // Prefer DecodeConfig because it's faster.
    r := bytes.NewReader(b)

    // Some formats are registered via blank imports (webp).
    if cfg, _, err := image.DecodeConfig(r); err == nil {
        if cfg.Width > 0 && cfg.Height > 0 {
            return imageMeta{width: cfg.Width, height: cfg.Height}, true
        }
    }

    // Fallback: try explicit decoders for common formats.
    r = bytes.NewReader(b)
    if cfg, err := png.DecodeConfig(r); err == nil {
        return imageMeta{width: cfg.Width, height: cfg.Height}, true
    }
    r = bytes.NewReader(b)
    if cfg, err := jpeg.DecodeConfig(r); err == nil {
        return imageMeta{width: cfg.Width, height: cfg.Height}, true
    }

    return imageMeta{}, false
}
