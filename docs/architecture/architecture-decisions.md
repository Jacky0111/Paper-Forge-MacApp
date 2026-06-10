# Paper Forge Architecture Decisions

This document is the current single source of truth for architecture, stack, and platform decisions.

It intentionally separates:

- approved decisions
- prototype-derived behavior
- open decisions that still require approval

## Status Summary

The repository has strong high-level direction, but most concrete implementation stacks are not yet formally decided.

### Fully Defined

- Application platform target: macOS desktop app
- Packaging target: signed, notarized `.app` distributed in a `.dmg`
- Repository layout and folder responsibilities
- Modular product direction with shared services and plugin-ready boundaries
- Prototype-to-production migration rule: `work/` is transitional, `src/` is canonical
- Frontend/UI framework: SwiftUI
- Desktop integration layer: AppKit where SwiftUI needs native macOS capabilities
- Core application/runtime language: Swift
- Document-processing helpers: Python only behind adapters for specialized processing
- Initial native scaffold: SwiftUI app shell, app container, core domain models, service protocols, and built-in module registry
- Phase 1 launch trio: PDF to Images, TXT to PDF, and Flatten PDF
- PDF to Images module boundary: native Swift module using PDFKit/AppKit rendering adapters
- TXT to PDF module boundary: native Swift module using CoreText/CoreGraphics PDF rendering
- Flatten PDF module boundary: native Swift module using PDFKit/CoreGraphics PDF rendering
- Local native preview packaging: `packaging/macos/build_native_app.sh` creates `outputs/Paper Forge Native.app`
- Native workflow UI: the SwiftUI app can select a module, choose input/output locations, run the module, and show output filenames
- Native launch controls: PDF image format/DPI, TXT font size/margins, Flatten PDF annotation option, and open output folder action
- Shared workflow layer: in-memory job queue, job status/progress model, visible job history, cancellation request hook, and persisted launch option settings
- Module execution progress/cancellation: `ModuleExecutionContext` carries progress and cancellation hooks, and all three Phase 1 modules report progress during execution
- Responsive MVP execution: module work runs off the main actor using a cancellation token so the SwiftUI window can remain responsive during conversions
- Release packaging scaffold: app metadata, sandbox entitlements, optional signing, and local `.dmg` generation live under `packaging/macos/`
- MVP icon pipeline: deterministic local icon generation creates `resources/AppIcon.icns`; image generation is not available in this session
- Release validation: `validate_release.sh` checks app bundle, icon, executable, DMG readability, signing status, and Gatekeeper status

### Partially Defined

- AI and OCR integration architecture
- Future plugin and module architecture
- Packaging and deployment strategy
- Configuration layering

### Mentioned but Incomplete

- Backend framework and technology stack
- Application architecture
- API design approach
- State management strategy
- Database strategy
- Authentication and authorization design
- Third-party dependency strategy
- Desktop application framework

### Missing

- A formally approved backend/runtime choice for application services
- A formally approved persistence strategy
- A formally approved auth model
- A formally approved API contract style

## Approved Decisions

### Product Form Factor

- Paper Forge is a macOS desktop application.
- The release artifact should be a native `.app` bundle packaged into a `.dmg`.
- The UI should be implemented with SwiftUI, using AppKit only where direct macOS integration is needed.
- The app should use Swift for the main runtime and service layer.
- Python should remain a helper runtime for specialized document processing, not the primary application framework.

### Repository Architecture

- `src/` is the canonical production source tree.
- `work/` remains transitional and prototype-only.
- Shared capabilities belong in platform services, not in feature UI code.
- Modules must not import each other directly unless a dependency is explicitly documented.
- Swift application code should live under `src/` once the native app scaffold is created.

### Capability Model

- The product is a modular document productivity platform.
- Built-in capabilities are organized as modules.
- Optional plugin loading should be controlled and capability-based.

### Shared Infrastructure

All future modules should be built on shared infrastructure for:

- import/export
- batch processing
- progress and cancellation
- structured errors
- logging and diagnostics
- settings
- localization
- licensing readiness
- plugin readiness
- update readiness
- analytics readiness
- AI service readiness

### Packaging Strategy

- Build an app bundle first.
- Sign and notarize before distributing.
- Package the app into a `.dmg`.
- Keep bundle metadata centralized.
- Preserve compatibility with macOS distribution constraints.

## Prototype-Derived Behavior

The current prototype in `work/` indicates the following, but these are not yet approved as final platform decisions:

- Python is being used for the prototype converter and packaging helper.
- A Tkinter-based UI shell is used by the prototype.
- Poppler command-line tools are used for PDF page inspection and rendering in the prototype.

These should be treated as implementation clues, not final architecture.

After approval of the macOS-native direction, the prototype implementation is no longer the target architecture for the production app.

## Open Decisions Requiring Approval

Before development proceeds beyond scaffolding, the following need explicit approval:

1. Frontend framework and UI stack
2. Backend/runtime framework for application services
3. Whether the app remains Python-based or migrates to another native stack
4. Whether the UI shell is native AppKit/SwiftUI, Python GUI, or a hybrid packaged runtime
5. State management approach for jobs, progress, and cancellation
6. Persistence strategy for settings, queues, history, and licensing data
7. API contract style between UI, modules, and services
8. Authentication and authorization model, if any
9. Dependency management and update strategy for third-party tools such as OCR and translation engines
10. Whether document processing happens in-process, through worker processes, or through a service boundary

## Recommended Canonical Maintenance Location

Keep future architecture decisions here in `docs/architecture/architecture-decisions.md`.

Use `AGENTS.md` for operating rules and roadmap context.

Use `CLAUDE.md` as the entry point for future Claude Code sessions so the canonical architecture document is immediately discoverable.
