# Paper Forge

Paper Forge is a modular macOS document productivity app — a native SwiftUI application for converting and optimising PDF and document files, built on a shared platform designed for future expansion.

## Shipped Modules

### Convert
| Module | Input | Output | Status |
|---|---|---|---|
| PDF to Images | PDF | PNG / JPG / TIFF | ✅ Shipped |
| TXT to PDF | TXT | PDF | ✅ Shipped |
| PDF to Word | PDF | .docx | ✅ Shipped |
| PDF to PPTX | PDF | .pptx | ✅ Shipped |
| PDF to Excel | PDF | .csv / .xlsx | ✅ Shipped |

### Optimise
| Module | Input | Output | Status |
|---|---|---|---|
| Flatten PDF | PDF | PDF | ✅ Shipped |
| Edit PDF | PDF | PDF | ✅ Shipped |

### Planned (Phase 3)
- Translate PDF — requires AI/translation service integration

## Stack

- **UI:** SwiftUI (macOS 14+)
- **Core:** Swift — PDFKit, CoreGraphics, CoreText, AppKit
- **Output formats:** Native OOXML (docx/pptx/xlsx) packaged via `/usr/bin/zip` — no third-party dependencies
- **Distribution:** Ad-hoc or Developer-ID signed `.app` in a `.dmg`

## Build

```sh
# Build the app bundle
bash packaging/macos/build_native_app.sh

# Build the distributable DMG
bash packaging/macos/build_release_dmg.sh

# Validate the release artifacts
bash packaging/macos/validate_release.sh
```

Output goes to `outputs/`.

## Repository Layout

```
src/pdfsuite/
  app/          — SwiftUI shell, AppState, ContentView
  core/         — domain models, contracts, errors
  modules/      — one folder per conversion module
  services/     — job queue, progress bus, settings, file I/O
packaging/macos/ — build, signing, notarisation, DMG scripts
resources/       — app icon assets
docs/architecture/ — architecture decisions, release notes
outputs/         — generated deliverables (gitignored)
work/            — transitional prototype helpers
```

## Development Notes

- All production code lives under `src/`; `work/` is transitional prototype material
- Each module implements `ModulePerforming` and registers a `ModuleManifest`
- Modules must not import each other directly
- Shared platform services (progress, cancellation, settings, job store) are injected via `AppContainer`
- Architecture decisions are the source of truth: [docs/architecture/architecture-decisions.md](./docs/architecture/architecture-decisions.md)

## License

Copyright 2026 Paper Forge. Licensed under the Apache License, Version 2.0. See [LICENSE](./LICENSE) for the full text.

## References

- [AGENTS.md](./AGENTS.md) — repository operating guide and roadmap
- [CLAUDE.md](./CLAUDE.md) — orientation for Claude Code sessions
- [docs/architecture/architecture-decisions.md](./docs/architecture/architecture-decisions.md) — canonical architecture decisions
- [docs/architecture/release-readiness.md](./docs/architecture/release-readiness.md) — release packaging notes
