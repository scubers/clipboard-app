#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DIR="$ROOT_DIR/core"
OUT_DIR="$CORE_DIR/build"

mkdir -p "$OUT_DIR"

pushd "$CORE_DIR" >/dev/null

echo "[core] go version: $(go version)"

go env -w CGO_ENABLED=1 >/dev/null 2>&1 || true

# Build a c-shared dylib + header
# Output: build/libclipboardtool.dylib and build/libclipboardtool.h

go build -buildmode=c-shared -o "$OUT_DIR/libclipboardtool.dylib" ./...

# Ensure dylib has an rpath-friendly install name.
if command -v install_name_tool >/dev/null 2>&1; then
  install_name_tool -id "@rpath/libclipboardtool.dylib" "$OUT_DIR/libclipboardtool.dylib" || true
fi

# Go emits a header next to the dylib with the same basename:
#   libclipboardtool.h
# We keep it but also copy to a stable name.
if [ -f "$OUT_DIR/libclipboardtool.h" ]; then
  cp "$OUT_DIR/libclipboardtool.h" "$OUT_DIR/clipboardtool.h"
fi

popd >/dev/null

echo "[core] built: $OUT_DIR/libclipboardtool.dylib"
