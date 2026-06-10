# Phase 1 Launch Scope

Paper Forge Phase 1 should launch with three tightly scoped features:

1. PDF to Images
2. TXT to PDF
3. Flatten PDF

The goal is to ship a native macOS product with a small but coherent document workflow surface.

## Scope Principles

- Keep each feature focused on one clear input and one clear output.
- Reuse the same app shell, file import/export, job handling, progress, and error surfaces.
- Avoid advanced layout reconstruction, OCR, translation, or editing complexity in Phase 1.
- Prefer deterministic output naming and predictable file locations.

## Feature 1: PDF to Images

### Goal

Convert each PDF page into image files.

### Minimum Launch Scope

- Select a PDF file
- Select an output folder
- Choose image format from `PNG`, `JPG`, or `TIFF`
- Choose output resolution from a simple DPI control
- Convert every page in the PDF into one image per page
- Show conversion progress and completion status
- Open the output folder after conversion

### Out of Scope for Launch

- OCR
- page range editing
- per-page format overrides
- batch presets
- cloud export

## Feature 2: TXT to PDF

### Goal

Convert plain text files into a simple, readable PDF.

### Minimum Launch Scope

- Select one or more `.txt` files
- Select an output folder
- Generate one PDF per input file
- Use a clean default page layout
- Support basic font size and margin settings
- Show progress and completion status

### Out of Scope for Launch

- rich text formatting
- embedded images
- tables
- multi-style documents
- page design templates
- PDF editing after creation

## Feature 3: Flatten PDF

### Goal

Create a flattened PDF output that preserves visual appearance while removing editable overlays where applicable.

### Minimum Launch Scope

- Select a PDF file
- Select an output folder
- Produce a flattened PDF copy
- Preserve page appearance as closely as possible
- Show progress and completion status

### Out of Scope for Launch

- form-field redesign
- annotation authoring
- selective layer flattening
- document rewriting tools
- advanced preflight repair

## Shared Launch Requirements

All three launch features must use the same shared infrastructure:

- app shell and navigation
- file import/export handling
- batch queue
- progress reporting and cancellation
- structured error messages
- settings storage
- logging and diagnostics
- a consistent output-folder flow

## Launch Success Criteria

Phase 1 is ready when:

- the app opens directly as a native macOS app
- all three features are reachable from the main UI
- each feature completes a basic end-to-end workflow
- failures are surfaced cleanly and do not crash the app
- outputs are deterministic and easy for users to find
