# Privacy and Security Notes

mcClippy stores clipboard history locally and should be treated as a sensitive-data application.

## Current Protections

- Clipboard data blobs are encrypted at rest with ChaChaPoly.
- The encryption key is stored in Keychain as `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Capture fails closed if the key cannot be persisted.
- Sensitive-looking content stores a placeholder preview instead of plaintext.
- Sensitive content can be pasted while hidden.
- Concealed/transient pasteboards and known password-manager markers are treated as sensitive signals, not automatic skips.
- Regular and pinned history both default to clearing once per Mac reboot, matching Windows clipboard history.
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
- Verify password-manager and concealed-marker pasteboards are captured as masked sensitive rows when content is present.
- Verify default reboot-scoped clearing removes persisted regular and pinned rows after a reboot.
- Verify clear-history actions remove the intended records.
- Verify a clean install shows onboarding and permission explanations.
