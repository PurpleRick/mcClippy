# Changelog

## Unreleased

## 1.0.2

- Fixed Enter/select auto-paste reliability by posting Command+V back to the target app.
- Improved local install signing stability for Accessibility permission testing.
- Reduced image-heavy UI memory work with cached thumbnails and lighter image capture.
- Published a packaged GitHub release artifact so users can install without Xcode.

## 1.0.1

- Added menu bar clipboard history app shell.
- Added floating keyboard-first history panel.
- Added Shift+Command+V global shortcut with customizable recorder.
- Added text, rich text, image, URL, and file URL capture.
- Added encrypted `dataBlob` storage using ChaChaPoly and Keychain.
- Added sensitive preview masking and reveal controls.
- Changed password-manager/concealed pasteboards to be captured as masked sensitive rows when content is present.
- Added app exclusions.
- Added auto-paste through Accessibility and CGEvent Command+V posting.
- Added launch-at-login setting.
- Added configurable history count, max item size, and separate regular/pinned retention policies.
- Added Settings link to the menu bar extra.
- Added rich text restore with HTML and plain-text pasteboard representations.
- Added clear unpinned, clear sensitive, clear images, and clear all controls.
- Added first-run onboarding.
- Added product readiness, architecture, privacy/security, release, troubleshooting, and README docs.
- Added initial unit tests for encryption, restore, and sensitive handling.
- Added macOS app icon assets.
