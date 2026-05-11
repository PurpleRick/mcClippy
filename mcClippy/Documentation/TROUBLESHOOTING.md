# Troubleshooting

## Shift+Command+V Does Not Open mcClippy

- Check Settings -> General and confirm the shortcut.
- Try resetting the shortcut to Shift+Command+V.
- Confirm another app is not already using the same global shortcut.
- Relaunch mcClippy.

## Enter Restores Clipboard But Does Not Paste

- Open Settings -> General.
- Enable "Paste selected item into the previous app on Enter."
- Grant Accessibility permission when prompted.
- Confirm App Sandbox is disabled in the Release build.

## Accessibility Permission Still Shows Missing

- Open System Settings -> Privacy & Security -> Accessibility.
- Remove mcClippy if it is already listed.
- Add mcClippy again.
- Quit and relaunch mcClippy.

## Exclusions Do Not Catch Every Copy

App exclusions are based on the frontmost app at polling time. If you copy and switch apps very quickly, macOS may not provide enough context for perfect attribution.

## Sensitive Items Are Hidden

This is expected. Click the eye button on a sensitive row to reveal it temporarily. Pasting works while the preview is hidden.

## History Does Not Include a Copied Item

Possible reasons:

- Monitoring is paused.
- Private mode is active.
- The current app is excluded.
- The pasteboard is marked concealed/transient.
- The item exceeds the configured maximum item size.
- Encryption key creation failed.
