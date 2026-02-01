---
name: pasty-release
description: Release workflow for the Pasty (clipboard-app) repo: preflight checks, create/push vX.Y.Z tag to trigger GitHub Actions DMG release, and optionally monitor CI.
---

# Pasty Release (tag → GitHub Actions → DMG)

Use this skill when the user asks to **发布/发版/release** Pasty, e.g. “发布 0.3.0 / 发一个版本 / 打 tag”.

## Guardrails (must)
- Workdir: repo root (expected: `clipboard-app/`).
- Never delete/retag existing release tags unless the user explicitly asks.
- If there are uncommitted changes, do **not** tag. Ask whether to commit, stash, or abort.

## Procedure
1) **Preflight**
   - `git status -sb`
   - Confirm target branch (usually `develop`).
   - Run minimal release checks:
     - `./scripts/build_macos_smoketest.sh`
     - `./scripts/build_macos_xcode.sh`
     - (Optional fast sanity) `./scripts/build_macos_app_bundle.sh <version>`

2) **Create tag**
   - Enforce strict format: `vX.Y.Z`.
   - `git tag -a vX.Y.Z -m "Pasty X.Y.Z"`
   - `git push origin vX.Y.Z`

3) **Monitor release (best-effort)**
   - If `gh` is available, fetch the newest run for `.github/workflows/release-dmg.yml` and report status.
   - Otherwise, tell the user where to check in GitHub Actions/Releases.

## Common failure triage hints
- Swift concurrency errors on CI: look for “captured var 'self' in concurrently-executing code”.
- XcodeGen drift: regenerate project via `./scripts/gen_xcodeproj.sh` and commit the `.xcodeproj` updates.
- dylib loading/rpath: ensure app bundle includes `Contents/Frameworks/libclipboardtool.dylib` and rpath `@executable_path/../Frameworks`.
