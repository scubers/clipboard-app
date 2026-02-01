#!/usr/bin/env bash
set -euo pipefail

# Assemble a runnable Pasty.app bundle.
#
# This script is the single source of truth for how we:
# - build the Go core dylib
# - sync SwiftPM Vendor/core artifacts (for linking)
# - build the SwiftPM executable
# - assemble the .app bundle layout and Info.plist
#
# Usage:
#   scripts/assemble_pasty_app.sh <version> <out-app-path>
#
# Examples:
#   scripts/assemble_pasty_app.sh 0.2.1 dist/Pasty.app
#   scripts/assemble_pasty_app.sh 0.0.0-dev /tmp/Pasty.app

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SPM_DIR="$ROOT_DIR/macos/ClipboardToolApp"

VERSION="${1:-}"
OUT_APP="${2:-}"

if [[ -z "$VERSION" || -z "$OUT_APP" ]]; then
  echo "Usage: $0 <version> <out-app-path>" >&2
  exit 2
fi

APP_NAME="Pasty"
BUNDLE_ID="com.jaylen.pasty.mac"

# Normalize OUT_APP to absolute path (so we can cd safely)
if [[ "$OUT_APP" != /* ]]; then
  OUT_APP="$ROOT_DIR/$OUT_APP"
fi

CONTENTS="$OUT_APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
FW_DIR="$CONTENTS/Frameworks"

mkdir -p "$(dirname "$OUT_APP")"

echo "[assemble] ${APP_NAME}.app version=${VERSION}"

# 1) Build Go core dylib
"$ROOT_DIR/scripts/build_core.sh"

# 2) Sync core artifacts into SwiftPM vendor folder (required for linking)
VENDOR_DIR="$APP_SPM_DIR/Vendor/core"
RES_DIR="$APP_SPM_DIR/Resources"
mkdir -p "$VENDOR_DIR" "$RES_DIR"
cp -f "$ROOT_DIR/core/build/libclipboardtool.dylib" "$VENDOR_DIR/libclipboardtool.dylib"
cp -f "$ROOT_DIR/core/build/clipboardtool.h" "$VENDOR_DIR/clipboardtool.h" || true

# Keep Resources dir present (Package.swift references ../../Resources)
mkdir -p "$APP_SPM_DIR/Resources"

# 3) Build SwiftPM release executable
pushd "$APP_SPM_DIR" >/dev/null
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_SRC="$BIN_DIR/ClipboardToolApp"
popd >/dev/null

if [[ ! -f "$BIN_SRC" ]]; then
  echo "[assemble] ERROR: built executable not found at: $BIN_SRC" >&2
  exit 1
fi

# 4) Assemble .app bundle
rm -rf "$OUT_APP"
mkdir -p "$MACOS_DIR" "$FW_DIR"

BIN_DST="$MACOS_DIR/$APP_NAME"
cp -f "$BIN_SRC" "$BIN_DST"
chmod +x "$BIN_DST"

cp -f "$ROOT_DIR/core/build/libclipboardtool.dylib" "$FW_DIR/libclipboardtool.dylib"

# Ensure the executable can locate the dylib
if command -v install_name_tool >/dev/null 2>&1; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$BIN_DST" 2>/dev/null || true
fi

# Remove quarantine bit if any (helps when moving around)
if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$OUT_APP" 2>/dev/null || true
fi

# Ad-hoc codesign (helps avoid "damaged" dialog on some systems)
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$OUT_APP" 2>/dev/null || true
fi

# Info.plist (align with release packaging)
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "[assemble] built: $OUT_APP"
