---
name: pasty-check
description: Spec-coding validation for the Pasty (clipboard-app) repo: ABI/link smoketest, XcodeGen + Xcode build, and local runnable app bundle build.
---

# Pasty Check (spec-coding validation)

Use this skill when the user asks to **跑检查/验证编译/自检/CI 前检查** for this repo.

## What this check covers (the "green" bar)
1) **Core ABI + Swift link smoketest**
   - `./scripts/build_macos_smoketest.sh`

2) **Xcode project consistency** (XcodeGen is source of truth)
   - `./scripts/build_macos_xcode.sh`

3) **Local runnable app bundle** (fast manual verification)
   - `./scripts/build_macos_app_bundle.sh`
   - (Optional) `open -n dist/Pasty.app`

## How to run
From repo root:
- Full check: run the 3 steps above.
- If the user is on a brand-new machine: suggest `./scripts/bootstrap_dev_macos.sh` first.

## Output expectations
- Print a short summary with PASS/FAIL for each step.
- On failure, paste the key compiler/linker error lines and the likely fix.
