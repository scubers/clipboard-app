#!/usr/bin/env bash
set -euo pipefail

# Build a runnable Pasty.app bundle for fast local verification.
# Output: dist/Pasty.app
#
# This script intentionally delegates to scripts/assemble_pasty_app.sh
# so the app assembly logic is shared with the DMG release build.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Determine version
ARG_VERSION="${1:-}"
if [[ -n "$ARG_VERSION" ]]; then
  ARG_VERSION="${ARG_VERSION#v}"
  VERSION="$ARG_VERSION"
else
  DESC="$(git -C "$ROOT_DIR" describe --tags --match 'v*.*.*' --always 2>/dev/null || true)"
  if [[ "$DESC" =~ ^v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    VERSION="${BASH_REMATCH[1]}"
  else
    VERSION="0.0.0-dev"
  fi
fi

OUT_APP="$ROOT_DIR/dist/Pasty.app"

"$ROOT_DIR/scripts/assemble_pasty_app.sh" "$VERSION" "$OUT_APP"

echo "[bundle] run: open -n '$OUT_APP'"
