#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/macos/ClipboardToolApp"
VENDOR_DIR="$APP_DIR/Vendor/core"
RES_DIR="$APP_DIR/Resources"

"$ROOT_DIR/scripts/build_core.sh"

mkdir -p "$VENDOR_DIR" "$RES_DIR"

# Copy dylib to Vendor/core for linking.
cp -f "$ROOT_DIR/core/build/libclipboardtool.dylib" "$VENDOR_DIR/libclipboardtool.dylib"

# Also keep a copy in Resources (useful later when we make a real .app bundle).
cp -f "$ROOT_DIR/core/build/libclipboardtool.dylib" "$RES_DIR/libclipboardtool.dylib"

cp -f "$ROOT_DIR/core/build/clipboardtool.h" "$VENDOR_DIR/clipboardtool.h" || true

pushd "$APP_DIR" >/dev/null
swift build -c debug
popd >/dev/null

echo "[macos-spm] build ok"
