#!/usr/bin/env bash
set -euo pipefail

# Bootstrap macOS dev dependencies for clipboard-app (Pasty)
# Assumptions:
# - You already cloned the repo
# - You already installed/configured OpenClaw (if you use it)
# - You're running this script from the repo root

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[bootstrap] repo: $ROOT_DIR"

SKIP_XCODEBUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-xcodebuild) SKIP_XCODEBUILD=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: scripts/bootstrap_dev_macos.sh [--skip-xcodebuild]

Options:
  --skip-xcodebuild   Skip the Xcode project build step (xcodebuild ... build)
  -h, --help          Show this help
EOF
      exit 0
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

section() {
  echo
  echo "==> $1"
}

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

section "Checking macOS"
if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "This script is for macOS (Darwin) only."
fi

section "Checking Xcode + Command Line Tools"
if ! need_cmd xcodebuild; then
  fail "xcodebuild not found. Install Xcode from App Store / Apple Developer, then run: xcode-select --install"
fi

if ! xcode-select -p >/dev/null 2>&1; then
  fail "Xcode Command Line Tools not configured. Run: xcode-select --install"
fi

# License acceptance can block CI-like builds.
# We can't auto-accept without sudo; just warn if it looks unaccepted.
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  echo "[warn] Xcode first-launch tasks may be pending. If builds fail, run: sudo xcodebuild -license accept"
fi

section "Checking Homebrew"
if ! need_cmd brew; then
  fail "brew not found. Install Homebrew first: https://brew.sh"
fi

section "Installing required formulae"
# Keep this list minimal and project-specific.
FORMULAE=(
  go
  xcodegen
)

for f in "${FORMULAE[@]}"; do
  if brew list --formula "$f" >/dev/null 2>&1; then
    echo "[brew] $f already installed"
  else
    echo "[brew] installing $f"
    brew install "$f"
  fi
done

section "Verifying toolchain"
echo "[tool] go:      $(go version)"
echo "[tool] xcodegen: $(xcodegen --version)"

section "Generating Xcode project"
./scripts/gen_xcodeproj.sh

section "Building Go core dylib"
./scripts/build_core.sh

section "SwiftPM build (debug)"
( cd macos/ClipboardToolApp && swift build )

if [[ "$SKIP_XCODEBUILD" == "1" ]]; then
  echo
  echo "==> Skipping Xcode build (Debug) (--skip-xcodebuild)"
else
  section "Xcode build (Debug)"
  # xcodegen writes to macos/Xcode/ClipboardTool.xcodeproj
  xcodebuild \
    -project macos/Xcode/ClipboardTool.xcodeproj \
    -scheme ClipboardTool \
    -configuration Debug \
    -sdk macosx \
    build
fi

echo
echo "[bootstrap] done"
