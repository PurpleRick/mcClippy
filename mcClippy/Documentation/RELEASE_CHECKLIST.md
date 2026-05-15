# Release Checklist

Releases are tag-driven. Push a `v*.*.*` tag and the workflow at [`.github/workflows/release.yml`](../../.github/workflows/release.yml) builds, ad-hoc signs, packages a zip + sha256, and publishes the GitHub Release.

## Pre-Tag Verification

- [ ] All tests green: `xcodebuild -project mcClippy.xcodeproj -scheme mcClippy -destination 'platform=macOS' -only-testing:mcClippyTests -parallel-testing-enabled NO test`
- [ ] Local Release build succeeds: `xcodebuild ... -configuration Release build`
- [ ] `CHANGELOG.md` has a section for the new version.
- [ ] `MARKETING_VERSION` will match the tag (the workflow injects it from the tag automatically).
- [ ] Spot-check on a fresh `tccutil reset Accessibility makmaj.mcClippy` to verify the Accessibility prompt and auto-paste flow.
- [ ] Spot-check the global shortcut after a sleep/wake cycle.
- [ ] If the bundle structure changed, confirm `PrivacyInfo.xcprivacy` landed in `Contents/Resources/`.

## Tag and Publish

```bash
git tag v1.1.x
git push origin v1.1.x
```

The workflow takes ~1–2 min. When it finishes, the release is at `https://github.com/PurpleRick/mcClippy/releases/tag/v1.1.x` with the zip + sha256 attached.

## Post-Release

- [ ] Verify the zip on a fresh user account or VM (Gatekeeper prompt + `xattr -dr` instruction).
- [ ] Update the install instructions in `README.md` if the version-bumped URL is referenced.

## Deferred until Apple Developer Enrollment

These steps activate once a paid Apple Developer Program membership is set up. The workflow has commented-out stubs.

- [ ] Add repository secrets: `APPLE_CERT_BASE64`, `APPLE_CERT_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_NOTARY_USER`, `APPLE_NOTARY_PASSWORD`.
- [ ] Replace `CODE_SIGN_IDENTITY="-"` with `"Developer ID Application"` and supply `DEVELOPMENT_TEAM`.
- [ ] Enable hardened runtime.
- [ ] After build, `xcrun notarytool submit ... --wait` and `xcrun stapler staple`.
- [ ] Repackage the zip with the stapled `.app`.
- [ ] Drop the `xattr -dr com.apple.quarantine` instruction from the release notes — Gatekeeper will trust the notarized build.

## Deferred until MAS Build (planned v1.2.0)

- [ ] Add `mcClippy.entitlements` with `com.apple.security.app-sandbox`.
- [ ] Add a `ReleaseMAS` build configuration.
- [ ] Implement SwiftData container migration so users upgrading from direct distribution find their history under the MAS sandbox container.
- [ ] App Store Connect setup + TestFlight beta cycle.
- [ ] Verify auto-paste under sandbox via the `kTCCServicePostEvent` TCC privilege (separate from full Accessibility).
