#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SPM_DIR="$ROOT_DIR/macos/ClipboardToolApp"

TAG="${1:-${GITHUB_REF_NAME:-}}"
if [[ -z "${TAG}" ]]; then
  echo "Usage: $0 vX.Y.Z" >&2
  exit 2
fi

if [[ ! "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid tag '${TAG}'. Expected strict vX.Y.Z" >&2
  exit 2
fi

VERSION="${TAG#v}"
APP_NAME="Pasty"
BUNDLE_ID="com.jaylen.pasty.mac"

DIST="$ROOT_DIR/dist"
WORK="$DIST/work"
DMG_ROOT="$WORK/dmgroot"
APP_BUNDLE="$DMG_ROOT/${APP_NAME}.app"

rm -rf "$WORK"
mkdir -p "$DMG_ROOT"

echo "[build] tag=${TAG} version=${VERSION}"

# 1) Build SwiftPM release executable
pushd "$APP_SPM_DIR" >/dev/null
swift --version
swift build -c release

# SwiftPM output path varies; use --show-bin-path for stability.
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_SRC="$BIN_DIR/ClipboardToolApp"
if [[ ! -f "$BIN_SRC" ]]; then
  echo "Built executable not found at: $BIN_SRC" >&2
  echo "Bin dir: $BIN_DIR" >&2
  ls -la "$BIN_DIR" || true
  exit 1
fi
popd >/dev/null

# 2) Assemble .app bundle
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

BIN_DST="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp -f "$BIN_SRC" "$BIN_DST"
chmod +x "$BIN_DST"

# Copy Go core dylib into app bundle Frameworks.
CORE_DYLIB_SRC="$ROOT_DIR/macos/ClipboardToolApp/Vendor/core/libclipboardtool.dylib"
if [[ ! -f "$CORE_DYLIB_SRC" ]]; then
  echo "Missing core dylib at: $CORE_DYLIB_SRC" >&2
  exit 1
fi
cp -f "$CORE_DYLIB_SRC" "$APP_BUNDLE/Contents/Frameworks/libclipboardtool.dylib"

# Ensure the executable can locate the dylib at runtime.
# Add rpath to Frameworks. (We don't remove existing rpaths; harmless.)
install_name_tool -add_rpath "@executable_path/../Frameworks" "$BIN_DST" || true

# Generate Info.plist
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
cat >"$INFO_PLIST" <<PLIST
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
</dict>
</plist>
PLIST

# Optional: provide Applications shortcut for drag-install UX
ln -sf /Applications "$DMG_ROOT/Applications"

# 3) Build DMG
mkdir -p "$DIST"
DMG_PATH="$DIST/${APP_NAME}-${VERSION}.dmg"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "[ok] built: $DMG_PATH"
