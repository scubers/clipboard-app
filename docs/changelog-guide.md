# Changelog Guide

This document provides guidelines for updating [CHANGELOG.md](../CHANGELOG.md) when making releases.

## Format

Use Keep a Changelog format (inspired by https://keepachangelog.com/en/1.0.0/):

```markdown
## [Unreleased]

### Added
- New feature A
- New feature B

### Changed
- Changed behavior X
- Updated dependency Y to version Z

### Fixed
- Fixed bug C
- Fixed issue #123

### Removed
- Removed deprecated feature D

---

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release
```

## Version Numbers

- Follow **Semantic Versioning** (SemVer): `MAJOR.MINOR.PATCH`
  - **MAJOR**: Incompatible API changes
  - **MINOR**: Backwards-compatible functionality additions
  - **PATCH**: Backwards-compatible bug fixes

## Categories

Use the following categories:

### Added
New features, new APIs, new UI components.

### Changed
Changes to existing functionality that don't break compatibility:
- Behavior changes
- Dependency updates
- Performance improvements
- Internal refactoring

### Fixed
Bug fixes, crash fixes, error handling improvements.

### Removed
Deprecated features or APIs that have been removed.

### Security
Security fixes or improvements.

## Writing Guidelines

1. **Be specific**: Describe what changed, not just that something changed
   - Good: "Added image clipboard support (PNG, TIFF, JPEG, WebP)"
   - Bad: "Added images"

2. **Group related changes**: Put related changes together under a single category

3. **Use active voice**: Start with past tense verbs
   - Good: "Fixed crash when deleting items"
   - Bad: "Crash when deleting items was fixed"

4. **Include links**: For major features, link to relevant documentation or issues

5. **Mention breaking changes**: Clearly indicate if an update requires user action

## Release Process

1. Update `CHANGELOG.md` with the new version section
2. Create a git tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
3. Push the tag: `git push origin v1.0.0`
4. GitHub Actions will automatically build and create the release

## Unreleased Section

Keep an `[Unreleased]` section at the top for changes that haven't been released yet. When you release:

1. Rename `[Unreleased]` to the version number and date
2. Create a new `[Unreleased]` section for future changes

## Examples

```markdown
## [Unreleased]

### Added
- Item tags feature with colored pills
- OCR image search using Vision framework
- Physical delete with blob cleanup

### Changed
- Improved clipboard handler architecture for better extensibility
- Updated search to include OCR text matching

### Fixed
- Fixed crash when deleting pinned items
- Fixed memory leak in image handler

---

## [0.4.0] - 2026-02-03

### Added
- File and folder copy handler: File URLs on clipboard are now properly detected and ignored
- New clipboard handler architecture with extensible type-based handlers

### Changed
- Replaced clipboard capture with modular handler system

---

## [0.1.0] - 2026-02-01

### Added
- Go core library (C ABI) with SQLite persistence
- Clipboard text capture pipeline
- macOS (SwiftUI) menu-bar app scaffold
```

## Related Documentation

- [CHANGELOG.md](../CHANGELOG.md) - The actual changelog file
- [planning/tasks-completed.md](../planning/tasks-completed.md) - Completed features
