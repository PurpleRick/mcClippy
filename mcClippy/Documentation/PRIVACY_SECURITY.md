# Privacy and Security Notes

mcClippy stores clipboard history locally and should be treated as a sensitive-data application.

## Current Protections

- Clipboard data blobs are encrypted at rest with ChaChaPoly.
- The encryption key is stored in Keychain as `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Capture fails closed if the key cannot be persisted.
- Sensitive-looking content stores a placeholder preview instead of plaintext.
- Sensitive content can be pasted while hidden.
- Concealed/transient pasteboards are skipped.
- Known password-manager pasteboard markers are skipped.
- App exclusions let users skip capture while specific bundle IDs are frontmost.
- Private mode pauses capture for a fixed duration.

## User-Facing Limitations

- Exclusions are best-effort because macOS does not reliably expose the source app that wrote the pasteboard.
- Auto-paste requires Accessibility permission.
- Auto-paste requires App Sandbox to remain disabled.
- If Accessibility is not granted, mcClippy restores the clipboard and returns focus, but the user must press Cmd+V manually.

## Sensitive Detection

The current detector flags common password/token markers and long token-like values. It is intentionally conservative but incomplete. It should be extended with tests before release.

## Release Requirements

- Verify no sensitive value is persisted in `plainTextPreview`.
- Verify encrypted data survives relaunch.
- Verify old plaintext sensitive previews are migrated to placeholders.
- Verify password-manager pasteboards are skipped.
- Verify clear-history actions remove the intended records.
- Verify a clean install shows onboarding and permission explanations.
