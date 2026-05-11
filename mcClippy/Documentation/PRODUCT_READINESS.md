# mcClippy Product Readiness

This document tracks what remains to turn mcClippy from a working prototype into a packaged macOS product.

## Current Status

| Area | Status | Notes |
| --- | --- | --- |
| App Sandbox | Done | Disabled for Debug and Release app target builds so Accessibility-driven auto-paste can post system-wide CGEvents. |
| Clipboard capture | In progress | Text, rich text/HTML, images, URLs, and file URLs are captured through `NSPasteboard.changeCount` polling. Source-app attribution and exclusions are best-effort because macOS pasteboard does not reliably expose the writer app. |
| Auto-paste | In progress | Enter restores the selected item, closes the panel, returns to the previous app, and posts Cmd+V when Accessibility permission is granted. |
| Sensitive handling | In progress | Concealed/transient pasteboard types are skipped. Sensitive previews are stored as placeholders and revealed from decrypted data only in memory. |
| Encryption at rest | In progress | `dataBlob` is sealed with ChaChaPoly using a Keychain-stored 256-bit key. Encryption fails closed if the key cannot be persisted. |
| App exclusions | In progress | User-defined bundle IDs are skipped while those apps are frontmost. This is not a hard guarantee that an excluded app can never be captured after rapid app switching. |
| Shortcut customization | In progress | Global Carbon hotkey defaults to Shift+Command+V and can be changed in Settings. |
| Floating panel UX | In progress | Keyboard selection, search, filters, reveal, pin, delete, paste-as-text, and context menu exist. Needs polish and edge-case testing. |
| Onboarding | In progress | First-run window explains shortcut, encryption, sensitive blur, password-manager skip, and exclusions. |
| Settings | In progress | General, Exclusions, and About tabs exist. History max count, max age, max item size, launch at login, and clear controls are now present. Needs final visual polish. |
| App icon and branding | In progress | App icon assets are present. Still needs menu bar icon review, bundle display name, and final product copy. |
| Launch at login | Done | Added `SMAppService.mainApp` registration with a Settings toggle. |
| Tests | In progress | Added unit tests for encryption, restore, sensitive placeholder behavior, sensitive detection, shortcut coding, exclusions, and history setting clamps. Still need UI tests for panel keyboard flow. |
| Signing and notarization | Not started | Needs Developer ID signing, hardened runtime review, notarization, and stapling. |
| Distribution package | Not started | Build a signed DMG or PKG and add release notes/changelog. |
| Support docs | Done | Added README, architecture, privacy/security, release checklist, troubleshooting, changelog, and product readiness docs. |

## Product Gaps To Close

1. Add product metadata.
2. Add UI tests for keyboard panel flow.
3. Add final product metadata.

## Known Limitations

- Clipboard monitoring is polling-based with `NSPasteboard.changeCount`.
- App exclusions are based on the frontmost app at polling time.
- Auto-paste requires Accessibility permission and a non-sandboxed app build.
- Password-manager skip relies on pasteboard type markers and known bundle/type conventions; it should remain conservative and easy to extend.

## Packaging Checklist

- [ ] Set final bundle display name.
- [ ] Set final bundle identifier.
- [ ] Set app category.
- [x] Add production app icon.
- [x] Verify App Sandbox remains disabled for release builds.
- [ ] Verify hardened runtime and signing settings.
- [ ] Archive Release build.
- [ ] Sign with Developer ID Application certificate.
- [ ] Notarize with Apple.
- [ ] Staple notarization ticket.
- [ ] Build signed DMG/PKG.
- [ ] Test install on a clean macOS user account.
- [ ] Verify Accessibility prompt and auto-paste flow.
- [ ] Verify encrypted history survives relaunch.
- [ ] Verify private mode and exclusions.
