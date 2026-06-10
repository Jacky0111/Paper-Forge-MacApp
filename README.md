# Paper Forge

Paper Forge is a modular macOS document productivity platform designed to grow from a small launch-ready foundation into a broader document workflow suite.

The project is currently architecture-first: the repo is organized for a native SwiftUI macOS app, shared services, built-in document modules, and future plugin expansion. Prototype helpers remain in `work/` until they are intentionally migrated into `src/`.

## What Paper Forge Is

Paper Forge is intended to become a professional desktop app for document conversion and preparation workflows, with a shared platform underneath rather than isolated one-off utilities.

Planned capability areas include:

- PDF to Images
- TXT to PDF
- Flatten PDF
- PDF to Word
- PDF to PPT/PPTX
- PDF to Excel/CSV
- Edit PDF
- Translate PDF

## Current Implementation Direction

The approved stack direction is:

- SwiftUI for the macOS interface
- Swift for the primary app/runtime and service layer
- Python only for specialized helper processing behind adapters

The canonical architecture and stack decisions live in [docs/architecture/architecture-decisions.md](./docs/architecture/architecture-decisions.md).

## Repository Layout

The repo is structured to keep production code, transitional prototypes, and packaging concerns separate:

- `src/` - canonical production source tree
- `work/` - transitional prototype helpers
- `packaging/` - macOS app bundle, signing, notarization, and DMG inputs
- `resources/` - app icon and static assets
- `config/` - version-controlled defaults and configuration overlays
- `docs/architecture/` - architectural decisions and release readiness notes
- `tests/` - unit, integration, and smoke tests
- `outputs/` - generated deliverables

## Launch Scope

The first launch target focuses on the foundation and the quickest shipping wins:

1. App shell and startup flow
2. File import/export
3. Batch queue and progress tracking
4. Structured errors and logging
5. Settings management
6. Launch-ready packaging for macOS
7. Phase 1 modules:
   - PDF to Images
   - TXT to PDF
   - Flatten PDF

See [docs/architecture/phase-1-launch-scope.md](./docs/architecture/phase-1-launch-scope.md) for the minimum scope definition.

## Build And Packaging

The macOS packaging workflow lives under [packaging/macos/](./packaging/macos/):

- `build_native_app.sh` builds the native `.app`
- `build_release_dmg.sh` packages the distributable `.dmg`
- `validate_release.sh` checks the app bundle and release artifacts
- `notarize_release.sh` prepares notarization for distribution

Generated deliverables are written to `outputs/`.

## Development Notes

- Keep production work in `src/`
- Treat `work/` as temporary prototype code
- Keep module boundaries explicit and shared services centralized
- Avoid direct module-to-module coupling unless it is intentionally documented
- Use the architecture decisions document as the source of truth for stack and platform choices

## License

Paper Forge is licensed under the Apache License, Version 2.0. See [LICENSE](./LICENSE) for the full text.

## References

- [AGENTS.md](./AGENTS.md) - repository operating guide and roadmap
- [CLAUDE.md](./CLAUDE.md) - short orientation for Claude Code sessions
- [docs/architecture/architecture-decisions.md](./docs/architecture/architecture-decisions.md) - canonical architecture decisions
- [docs/architecture/release-readiness.md](./docs/architecture/release-readiness.md) - release packaging notes
