# Documentation Index

This directory contains all project documentation for Pasty (macOS Clipboard Tool).

## Quick Links

- [Development Guide](development.md) - Setup, build workflow, and coding rules
- [Design Decisions](decisions.md) - Architectural and design decisions

---

## By Category

### Product Specifications (`spec/`)

- [Overview](spec/overview.md) - Product goals, scope, and high-level architecture
- [Core ABI](spec/core-abi.md) - Complete C API specification
- [Data Model](spec/data-model.md) - SQLite schema and data structure

### Design (`design/`)

- [UI Spec](design/ui.md) - Main panel UI/UX design
- [Settings Spec](design/settings.md) - Settings panel design
- [Features](design/features/) - Individual feature designs
  - [OCR Search](design/features/ocr-search.md)
  - [Delete Item](design/features/delete-item.md)
  - [Tags](design/features/tags.md)

### Architecture (`architecture/`)

- [Overview](architecture/overview.md) - System architecture, components, and data flow
- [macOS Architecture](architecture/macos.md) - macOS app structure and dependency rules
- [Clipboard Handler](architecture/clipboard-handler.md) - Handler pattern implementation

### Planning (`planning/`)

- [Tasks](planning/tasks.md) - Current milestone tracking
- [Tasks Completed](planning/tasks-completed.md) - Completed milestones and features
- [Backlog](planning/backlog.md) - Future improvements

### Guides

- [CHANGELOG Guide](changelog-guide.md) - Guidelines for version updates

---

## Document Types Explained

### Product Specifications (`spec/`)
Define **what** we're building:
- Product goals and scope
- Architecture decisions
- Data models and schemas
- API contracts

### Design (`design/`)
Define **how** it should look and behave:
- UI/UX specifications
- Feature designs with acceptance criteria
- Interaction patterns

### Architecture (`architecture/`)
Define **how** it's implemented:
- Directory structure
- Dependency rules
- Design patterns
- Component responsibilities

### Planning (`planning/`)
Track **progress and future work**:
- Active milestones
- Completed features
- Backlog items

---

## For New Contributors

1. Start with [Development Guide](development.md) to set up your environment
2. Read [Overview](spec/overview.md) to understand product scope
3. Review [macOS Architecture](architecture/macos.md) for code structure
4. Check [Tasks](planning/tasks.md) for current priorities

---

## Maintaining Documentation

- Keep specs in sync with code - update when APIs or designs change
- Document decisions in [Design Decisions](decisions.md) when making trade-offs
- Update [CHANGELOG Guide](changelog-guide.md) when making releases
