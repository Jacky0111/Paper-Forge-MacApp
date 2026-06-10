# macOS Packaging

Use this folder for future `.app`, `.dmg`, code signing, notarization, and release packaging assets.

## Native SwiftUI Preview Build

Use `build_native_app.sh` to compile the current SwiftUI source scaffold into `outputs/Paper Forge.app`.

This helper creates an ad-hoc signed local preview app for development. Public release builds still need Developer ID signing, notarization, and `.dmg` packaging before distribution.

## Release DMG Build

Use `build_release_dmg.sh` to create `outputs/Paper Forge-0.1.0.dmg`.

Set `PAPER_FORGE_SIGN_IDENTITY` to a Developer ID Application signing identity to sign the staged `.app` and final `.dmg`. If the variable is omitted, the script creates an ad-hoc signed local `.app` inside an unsigned local `.dmg` for packaging verification only.

Check installed signing identities with:

```bash
security find-identity -v -p codesigning
```

Release metadata is centralized in `app-metadata.env`.
Sandbox-ready entitlements are tracked in `PaperForge.entitlements`.

## App Icon

Use `generate_app_icon.sh` to create the deterministic MVP icon at `resources/AppIcon.icns`.

This is a local generated placeholder, not an AI-generated image. Replace it with a designer-produced production icon before final public launch if brand polish matters.

## Notarization

Use `notarize_release.sh` after creating a signed `.dmg`.

Required environment variables:

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_PASSWORD`

## Validation

Use `validate_release.sh` to inspect the built `.app` and `.dmg`, including plist validity, icon presence, executable type, DMG readability, signing status, and Gatekeeper status.

For the public launch checklist and Mac App Store considerations, see [../../docs/architecture/release-readiness.md](../../docs/architecture/release-readiness.md).
