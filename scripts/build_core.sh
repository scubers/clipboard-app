#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DIR="$ROOT_DIR/core"
OUT_DIR="$CORE_DIR/build"

# Xcode GUI builds often run with a minimal PATH (missing Homebrew).
# Ensure common Homebrew locations are present.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

GO_BIN="${GO_BIN:-}"
if [ -z "$GO_BIN" ]; then
  GO_BIN="$(command -v go 2>/dev/null || true)"
fi
if [ -z "$GO_BIN" ]; then
  echo "[core] ERROR: go not found in PATH. Install Go or set GO_BIN=/path/to/go" >&2
  echo "[core] PATH=$PATH" >&2
  exit 127
fi

mkdir -p "$OUT_DIR"

pushd "$CORE_DIR" >/dev/null

echo "[core] go version: $($GO_BIN version)"

"$GO_BIN" env -w CGO_ENABLED=1 >/dev/null 2>&1 || true

# Build a c-shared dylib + header
# Output: build/libclipboardtool.dylib and build/libclipboardtool.h

"$GO_BIN" build -buildmode=c-shared -o "$OUT_DIR/libclipboardtool.dylib" ./...

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
