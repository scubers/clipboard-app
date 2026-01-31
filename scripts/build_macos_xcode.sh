#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT_DIR/macos/Xcode/ClipboardTool.xcodeproj"
SCHEME="ClipboardTool"

# Regenerate project (Xcode project file is generated; keep it in sync with new/removed sources)
"$ROOT_DIR/scripts/gen_xcodeproj.sh"

xcodebuild -project "$PROJ" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build

echo "[xcodebuild] ok"
