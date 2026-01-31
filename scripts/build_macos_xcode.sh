#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT_DIR/macos/Xcode/ClipboardTool.xcodeproj"
SCHEME="ClipboardTool"

# Regenerate project if missing
if [ ! -d "$PROJ" ]; then
  "$ROOT_DIR/scripts/gen_xcodeproj.sh"
fi

xcodebuild -project "$PROJ" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build

echo "[xcodebuild] ok"
