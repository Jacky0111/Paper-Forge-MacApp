# Repository Operating Guide

## Objective

Prepare this repository for Paper Forge, a professional macOS desktop application distributed as a signed and notarized `.dmg`.

This project is currently in architecture-first mode:
- do not add feature implementation unless explicitly requested
- do not put business logic in the UI shell
- do not couple future modules to each other directly
- keep the repo ready for scalable document-productivity expansion

## Current State

- `work/` contains the prototype converter and temporary packaging helper
- `outputs/` contains generated deliverables
- `src/` is the canonical application source tree for future development

Treat `work/` as transitional. New production code belongs under `src/`.

## Product Vision

Build Paper Forge as a modular document productivity suite with these planned capabilities:
- PDF to Images
- PDF to Word
- Edit PDF
- Flatten PDF
- Translate PDF
- TXT to PDF
- PDF to PPT/PPTX
- PDF to Excel/CSV

Design everything as a shared platform, not as isolated utilities.

## Complexity Order

Use this order when planning or prioritizing work, from easiest to hardest:

1. PDF to Images
2. TXT to PDF
3. Flatten PDF
4. PDF to Word
5. PDF to PPT/PPTX
6. PDF to Excel/CSV
7. Edit PDF
8. Translate PDF

Important:
- If "Edit PDF" is scoped to simple operations only, it may move earlier.
- If translation becomes text-only without layout preservation, it may become less complex, but a polished user-facing feature remains high effort.

## Roadmap

### Phase 1: Foundation and Quick Wins

Prioritize:
- app shell and startup flow
- file import/export
- batch queue
- progress tracking
- structured errors
- logging
- settings management
- licensing hooks
- analytics hooks
- update readiness

Ship first:
- PDF to Images
- TXT to PDF
- Flatten PDF

For the minimum launch definition of those three features, see [docs/architecture/phase-1-launch-scope.md](./docs/architecture/phase-1-launch-scope.md).

### Phase 2: Revenue Expansion

Add:
- PDF to Word
- PDF to PPT/PPTX
- scoped Edit PDF actions if the scope is narrow and well-defined

### Phase 3: Advanced Intelligence

Add:
- PDF to Excel/CSV
- Translate PDF
- OCR-enabled extraction
- AI-assisted document workflows
- advanced editing

## Repository Structure

Keep the repository organized like this:

```text
.
├── AGENTS.md
├── README.md
├── pyproject.toml
├── config/
├── docs/
├── packaging/
├── resources/
├── scripts/
├── src/
│   └── pdfsuite/
│       ├── app/
│       ├── core/
│       ├── integrations/
│       ├── modules/
│       ├── plugins/
│       ├── services/
│       └── ui/
├── tests/
├── work/
└── outputs/
```

### Folder Responsibilities

- `src/pdfsuite/app/`
  - app startup, composition, routing, lifecycle
- `src/pdfsuite/core/`
  - shared models, workflow primitives, errors, logging helpers, utilities
- `src/pdfsuite/modules/`
  - one folder per conversion capability
- `src/pdfsuite/integrations/`
  - adapters for OCR, translation, AI, and third-party services
- `src/pdfsuite/plugins/`
  - future plugin discovery and registration
- `src/pdfsuite/services/`
  - file import/export, batch queue, progress bus, settings, licensing, telemetry, updates
- `src/pdfsuite/ui/`
  - macOS-facing UI composition and reusable presentation components
- `config/`
  - defaults, overlays, and feature flags
- `docs/architecture/`
  - architecture notes, module scorecards, packaging notes, release planning
- `packaging/macos/`
  - app bundle, signing, notarization, and DMG inputs
- `resources/`
  - icons, localization assets, templates, static resources
- `tests/`
  - unit, integration, and regression tests

## Shared Infrastructure Rules

Every future module must use the same platform services:
- file import and export handling
- batch processing
- progress reporting and cancellation
- structured error handling
- logging and diagnostics
- settings storage
- localization
- licensing readiness
- plugin readiness
- update readiness
- analytics readiness
- AI service readiness

## Module Boundaries

Each module must:
- expose a stable manifest
- validate its inputs
- depend only on shared core services and explicit adapters
- return standardized results
- keep UI concerns out of the module implementation

Do not let modules import each other directly unless there is a documented, intentional dependency.

## Plugin Strategy

Design for plugins early:
- each module should have a manifest
- the app should discover built-in modules first
- optional plugins should load through controlled registration
- the app should rely on stable capability interfaces, not hard-coded feature coupling

## Configuration Strategy

Use layered config:
1. defaults in version-controlled files
2. user preferences stored locally
3. runtime overrides from feature flags or enterprise profiles
4. packaging-time environment values

Avoid hard-coded machine-specific paths in source-controlled files.

## macOS Packaging Strategy

Plan for direct-download distribution first:
- build an `.app`
- sign it
- notarize it
- package it into a `.dmg`
- support a future signed update mechanism

Keep bundle metadata centralized:
- bundle identifier
- version
- icon assets
- resource lookup
- entitlements
- hardened runtime settings

Keep App Store constraints in mind:
- avoid unsafe self-modification
- avoid tight coupling to external helpers that cannot be sandboxed
- keep file access patterns compatible with macOS expectations

## Licensing, Analytics, and AI

Keep these behind service interfaces:
- licensing/entitlements
- telemetry/analytics
- AI providers

Never hard-code vendor APIs inside UI code or feature modules.

## Development Standards

- Prefer small, testable services.
- Keep business rules out of the UI layer.
- Use deterministic file naming and export paths.
- Preserve backward compatibility when adding new modules.
- Document any new shared contract immediately.
- Write tests alongside module boundaries.
- Keep prototype code in `work/` until it is intentionally migrated.

## Release Strategy

Recommended release flow:
1. implement in `src/`
2. test the shared service contracts
3. build the app bundle
4. sign and notarize the build
5. package the `.dmg`
6. publish release metadata and notes

Releases should be reproducible and not depend on manual terminal steps from the end user.

## Long-Term Expansion

Keep the architecture ready for:
- OCR workflows
- multilingual conversion
- enterprise profiles
- cloud export integrations
- plugin marketplace support
- AI-assisted document understanding
- future native macOS UI modernization

## Working Rule

Before implementing a new feature:
1. define the module boundary
2. identify the shared services it needs
3. update the module manifest
4. confirm batch/progress/error behavior
5. document packaging impact
6. add tests before expanding scope

This repo should evolve like a platform, not a pile of scripts.

## Architecture Decision Source Of Truth

Keep canonical architecture decisions in [docs/architecture/architecture-decisions.md](./docs/architecture/architecture-decisions.md).

Update that document whenever a frontend, backend, storage, API, packaging, integration, or module boundary decision is approved.

Use this file for operating rules, roadmap, and repository conventions; do not duplicate detailed stack decisions here unless they are needed for workflow guidance.
