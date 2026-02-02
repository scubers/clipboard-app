---
name: macos-verify-build
description: macOS development build verification workflow. Runs gen_xcodeproj.sh and build_macos_app_bundle.sh to ensure code changes build successfully.
---
# macOS Build Verification

Use this skill when user asks to **验证编译/构建 macOS 应用**.

## Steps

1. **Generate Xcode project**
   - Ensures file structure is correct via XcodeGen
   ```bash
   ./scripts/gen_xcodeproj.sh
   ```

2. **Build and verify**
   - Assembles runnable `.app` bundle
   - Verifies build succeeds
   ```bash
   ./scripts/build_macos_app_bundle.sh
   ```

3. **Optional: Run and test**
   - Quick manual verification
   ```bash
   open -n dist/Pasty.app
   ```

## Output expectations

- **Success**: Prints summary showing each step PASSed
- **Failure**: Prints step name, compiler/linker error lines, and likely fix
- **Clean run**: Should produce `dist/Pasty.app` and show no errors

## When to use

- After modifying macOS app code (Swift/SwiftUI files)
- After adding/removing/moving source files
- Before committing changes

## Common failure scenarios

| Error | Likely fix |
|--------|-------------|
| "use [:] to get an empty dictionary literal" | Options parameter should be `[:]` not `[]` |
| "cannot find 'X' in scope" | Missing import or file not added to project |
| "reference to member 'fileURL' cannot be resolved without a contextual type" | Type inference issue, add explicit cast |
| XcodeGen errors (project generation fails) | Check YAML syntax in `project.yml` |
