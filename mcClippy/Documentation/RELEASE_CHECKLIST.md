# Release Checklist

## Before Archive

- [ ] Confirm `ENABLE_APP_SANDBOX = NO` for Release.
- [ ] Confirm bundle display name.
- [ ] Confirm bundle identifier.
- [ ] Confirm app category.
- [ ] Add final app icon.
- [ ] Confirm version and build number.
- [ ] Run unit tests.
- [ ] Run UI tests.
- [ ] Test first launch on a clean user account.
- [ ] Test Accessibility permission request.
- [ ] Test auto-paste into TextEdit, Safari, Terminal, and a password field.
- [ ] Test private mode.
- [ ] Test app exclusions.
- [ ] Test encrypted history after relaunch.

## Archive and Sign

- [ ] Select Release configuration.
- [ ] Archive in Xcode.
- [ ] Sign with Developer ID Application certificate.
- [ ] Enable hardened runtime if needed by distribution workflow.
- [ ] Export notarization-ready app.

## Notarize

- [ ] Submit to Apple notary service.
- [ ] Wait for notarization success.
- [ ] Staple ticket to app.
- [ ] Verify Gatekeeper accepts the app on a clean machine.

## Package

- [ ] Create signed DMG or PKG.
- [ ] Include app and Applications shortcut if using DMG.
- [ ] Verify package install/uninstall behavior.
- [ ] Verify app launches after install.
- [ ] Verify login item setting works after install.

## Publish

- [ ] Publish release notes.
- [ ] Publish privacy/security notes.
- [ ] Publish troubleshooting steps for Accessibility and auto-paste.
- [ ] Tag release in source control.
