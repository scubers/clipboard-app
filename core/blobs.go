package main

import (
    "crypto/sha256"
    "encoding/hex"
    "fmt"
    "os"
    "path/filepath"
)

func sha256HexBytes(b []byte) string {
    h := sha256.Sum256(b)
    return hex.EncodeToString(h[:])
}

func ensureBlobsDir(dataDir string) (string, error) {
    dir := filepath.Join(dataDir, "data", "blobs")
    if err := os.MkdirAll(dir, 0o755); err != nil {
        return "", fmt.Errorf("mkdir blobs dir: %w", err)
    }
    return dir, nil
}

func writeBlobFile(dataDir, id, ext string, b []byte) (string, int64, error) {
    blobsDir, err := ensureBlobsDir(dataDir)
    if err != nil {
        return "", 0, err
    }
    if ext == "" {
        ext = "bin"
    }
    name := id + "." + ext
    p := filepath.Join(blobsDir, name)
    if err := os.WriteFile(p, b, 0o644); err != nil {
        return "", 0, fmt.Errorf("write blob: %w", err)
    }
    return p, int64(len(b)), nil
}
