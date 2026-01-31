#!/usr/bin/env bash
set -euo pipefail

# Build a runnable macOS .app bundle from the SwiftPM executable + Go dylib.
# This is not an Xcode project yet, but it produces a proper .app structure
# suitable for manual testing and future packaging.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SPM_DIR="$ROOT_DIR/macos/ClipboardToolApp"
APP_NAME="ClipboardTool"
BUNDLE_ID="com.jaylen.clipboardtool"
OUT_DIR="$ROOT_DIR/dist"
APP_DIR="$OUT_DIR/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

"$ROOT_DIR/scripts/build_core.sh"

pushd "$APP_SPM_DIR" >/dev/null
swift build -c release
popd >/dev/null

BIN="$APP_SPM_DIR/.build/arm64-apple-macosx/release/ClipboardToolApp"
if [ ! -f "$BIN" ]; then
  # Fallback path on some SwiftPM versions
  BIN="$APP_SPM_DIR/.build/release/ClipboardToolApp"
fi

if [ ! -f "$BIN" ]; then
  echo "[bundle] Could not find built executable. Looked for ClipboardToolApp under .build/*/release"
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# Copy executable
cp -f "$BIN" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy core dylib into Resources
cp -f "$ROOT_DIR/core/build/libclipboardtool.dylib" "$RES_DIR/libclipboardtool.dylib"

# Ensure the executable can locate the dylib
if command -v install_name_tool >/dev/null 2>&1; then
  install_name_tool -add_rpath "@executable_path/../Resources" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true
fi

# Minimal Info.plist
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "[bundle] built: $APP_DIR"
echo "[bundle] run: open -n '$APP_DIR'"
