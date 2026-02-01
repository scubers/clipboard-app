#!/usr/bin/env bash
set -euo pipefail

# Build a runnable macOS .app bundle from the SwiftPM executable + Go dylib.
# Output: dist/Pasty.app
#
# This is meant for fast local verification:
#   ./scripts/build_macos_app_bundle.sh
#   open -n dist/Pasty.app
#
# Optional:
#   ./scripts/build_macos_app_bundle.sh 0.2.1
#   ./scripts/build_macos_app_bundle.sh v0.2.1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SPM_DIR="$ROOT_DIR/macos/ClipboardToolApp"

APP_NAME="Pasty"
BUNDLE_ID="com.jaylen.pasty.mac"

OUT_DIR="$ROOT_DIR/dist"
APP_DIR="$OUT_DIR/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
FW_DIR="$CONTENTS/Frameworks"

# Determine version
ARG_VERSION="${1:-}"
if [[ -n "$ARG_VERSION" ]]; then
  # Accept either 0.2.1 or v0.2.1
  ARG_VERSION="${ARG_VERSION#v}"
  VERSION="$ARG_VERSION"
else
  # Best-effort from git tag; fallback to 0.0.0-dev
  DESC="$(git -C "$ROOT_DIR" describe --tags --match 'v*.*.*' --always 2>/dev/null || true)"
  if [[ "$DESC" =~ ^v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    VERSION="${BASH_REMATCH[1]}"
  else
    VERSION="0.0.0-dev"
  fi
fi

mkdir -p "$OUT_DIR"

echo "[bundle] building ${APP_NAME}.app version=${VERSION}"

# 1) Build Go core dylib
"$ROOT_DIR/scripts/build_core.sh"

# 2) Build SwiftPM release executable
pushd "$APP_SPM_DIR" >/dev/null
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_SRC="$BIN_DIR/ClipboardToolApp"
popd >/dev/null

if [[ ! -f "$BIN_SRC" ]]; then
  echo "[bundle] ERROR: built executable not found at: $BIN_SRC" >&2
  exit 1
fi

# 3) Assemble .app bundle
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$FW_DIR"

BIN_DST="$MACOS_DIR/$APP_NAME"
cp -f "$BIN_SRC" "$BIN_DST"
chmod +x "$BIN_DST"

# Put dylib in Frameworks (same as release DMG flow)
cp -f "$ROOT_DIR/core/build/libclipboardtool.dylib" "$FW_DIR/libclipboardtool.dylib"

# Ensure executable can locate the dylib
if command -v install_name_tool >/dev/null 2>&1; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$BIN_DST" 2>/dev/null || true
fi

# Sanity checks
[[ -f "$BIN_DST" ]] || { echo "[bundle] ERROR: missing executable at $BIN_DST" >&2; exit 1; }
[[ -f "$FW_DIR/libclipboardtool.dylib" ]] || { echo "[bundle] ERROR: missing dylib at $FW_DIR/libclipboardtool.dylib" >&2; exit 1; }

# Remove quarantine bit if any (helps when moving around)
if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true
fi

# Ad-hoc codesign (helps avoid "damaged" dialog on some systems)
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
fi

# Info.plist (align with DMG build as much as possible)
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

echo "[bundle] built: $APP_DIR"
echo "[bundle] run: open -n '$APP_DIR'"
