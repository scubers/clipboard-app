#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install with: brew install xcodegen" >&2
  exit 1
fi

cd "$ROOT_DIR/macos/Xcode"
xcodegen generate

echo "[xcodegen] generated: $ROOT_DIR/macos/Xcode/ClipboardTool.xcodeproj"
