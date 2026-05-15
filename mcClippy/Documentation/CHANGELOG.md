# Changelog

## Unreleased

## 1.1.1

- Bundle ID validation: the Exclusions tab now rejects malformed entries (`banana`, `hello.world`) with an inline error and only accepts reverse-DNS-shaped strings.
- "Exclude Frontmost App" no longer adds mcClippy to its own exclusion list when invoked from the menu bar or Settings.
- "Clear All" in the Exclusions tab now asks for confirmation — it wipes pinned items too, and the previous behavior had no undo path.
- About panel now shows the version and build number, plus links to the GitHub project and Releases page.
- Fixed a latent silent-data-loss in the Maximum Item Size stepper: integer division previously truncated non-MB-aligned byte counts. The displayed MB value now rounds to nearest, so a 5.5 MB stored value shows as 6 MB instead of silently snapping to 5.

## 1.1.0

- Added on-demand text extraction from images: right-click any image item and choose **Paste as Text** to OCR it via Apple's Vision framework. Runs locally on this Mac — no network, no entitlement. Extracted text is cached on the item, so the second time is instant.
- Extracted text becomes searchable: typing in the panel search box now matches OCR'd content from screenshots and image clipboard items.
- A spinner appears on the row's thumbnail while extraction is in progress.
- OCR'd text is run through the sensitive-content detector, so screenshots of password managers, `.env` files, or 2FA codes get the same masking treatment as text captures.
- Added a Settings toggle to disable the feature (under General → Text Extraction).
- Menu-bar "Pause Monitoring" / "Private Mode" labels now reflect the actual current state ("Resume Monitoring" / "Private Mode (Active)") instead of being static.
- Destructive clear actions in the menu and Exclusions panel now explicitly save the model context (no longer rely on autosave).

## 1.0.3

- Fixed the global shortcut becoming unresponsive after the Mac sleeps and wakes — the Carbon hotkey now re-registers on wake and session-active notifications.
- Improved auto-paste reliability: waits for the target app to actually become frontmost (up to ~400 ms) before posting ⌘V, and switched to the HID event tap which is more reliable across destination apps.
- Always restores focus to the previously-active app on paste, even when auto-paste is disabled or fails.
- Fixed a race condition where the floating panel could leak keyboard event monitors when dismissed by clicking outside the panel.
- Fixed a crash in the Settings panel when changing the "Keep up to N items" or "Maximum item size" sliders — the clamping logic ran into infinite recursion via the `@Published didSet`.

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
