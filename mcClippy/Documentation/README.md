# mcClippy

mcClippy is a local-first macOS menu bar clipboard history app inspired by Windows Win+V.

## Core Workflow

1. Copy text, links, files, or images.
2. Press `⇧⌘V` (rebindable in Settings).
3. Search or use arrow keys to select a history item — the search box matches captured text, source app names, and OCR'd text from screenshots.
4. Press Return to paste into the previous app.

If Accessibility permission is not granted, mcClippy still restores the selected item to the clipboard and returns focus to the previous app so you can press `⌘V` manually.

For image items, right-click and choose **Extract & Paste as Text** to OCR the image via Apple Vision and paste the recognized text instead of the image itself. The result is cached on the item, so the second extraction is instant.

## Privacy Model

- Clipboard data is stored locally — no network, no iCloud sync.
- Data blobs are encrypted at rest with ChaChaPoly using a Keychain-stored key.
- Sensitive-looking previews are hidden by default.
- OCR runs locally via Apple's Vision framework; the extracted text is also checked against the sensitive-content detector, so screenshots of password manager UIs auto-flag as sensitive.
- Concealed/transient pasteboards and known password-manager pasteboard markers are captured as sensitive items when supported content is present.
- Regular and pinned items both default to clearing once per Mac reboot; each retention policy can be changed separately in Settings.
- App exclusions skip captures while selected bundle IDs are frontmost.

## Requirements

- macOS 14.0 or later (Sonoma).
- App Sandbox is currently disabled for direct distribution to enable `CGEvent`-based auto-paste. A sandboxed Mac App Store build using the `kTCCServicePostEvent` TCC privilege is planned.
- Accessibility permission for automatic Command+V posting (optional — without it, the clipboard is still restored and the user can press `⌘V` manually).

## Development Notes

- Architecture notes live in [`ARCHITECTURE.md`](ARCHITECTURE.md).
- Privacy + security details live in [`PRIVACY_SECURITY.md`](PRIVACY_SECURITY.md).
- Release workflow steps live in [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md).
- User-facing troubleshooting steps live in [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).
- Version history lives in [`CHANGELOG.md`](CHANGELOG.md).
