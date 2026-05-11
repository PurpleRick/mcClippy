# mcClippy

mcClippy is a local-first macOS menu bar clipboard history app inspired by Windows Win+V.

## Core Workflow

1. Copy text, links, files, or images.
2. Press Shift+Command+V.
3. Search or use arrow keys to select a history item.
4. Press Return to paste into the previous app.

If Accessibility permission is not granted, mcClippy still restores the selected item to the clipboard and returns focus to the previous app so you can press Command+V manually.

## Privacy Model

- Clipboard data is stored locally.
- Data blobs are encrypted at rest with ChaChaPoly.
- Sensitive-looking previews are hidden by default.
- Concealed/transient pasteboards and known password-manager pasteboard markers are captured as sensitive items when supported content is present.
- Regular and pinned items both default to clearing once per Mac reboot; each retention policy can be changed separately in Settings.
- App exclusions skip captures while selected bundle IDs are frontmost.

## Requirements

- macOS target configured by the Xcode project.
- App Sandbox disabled for auto-paste.
- Accessibility permission for automatic Command+V posting.

## Development Notes

- Product readiness is tracked in `PRODUCT_READINESS.md`.
- Architecture notes live in `ARCHITECTURE.md`.
- Privacy notes live in `PRIVACY_SECURITY.md`.
- Release steps live in `RELEASE_CHECKLIST.md`.
