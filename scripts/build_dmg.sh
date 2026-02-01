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

# 1) Assemble .app bundle (single source of truth)
# This will also build core dylib and the SwiftPM release executable.
"$ROOT_DIR/scripts/assemble_pasty_app.sh" "$VERSION" "$APP_BUNDLE"

# Optional: provide Applications shortcut for drag-install UX
ln -sf /Applications "$DMG_ROOT/Applications"

# 2) Build DMG
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
