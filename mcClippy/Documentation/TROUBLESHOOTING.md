# Troubleshooting

## Shift+Command+V Does Not Open mcClippy

- Check Settings → General and confirm the shortcut.
- Try resetting the shortcut to Shift+Command+V.
- Confirm another app is not already using the same global shortcut.
- If it stopped working after a Mac restart or install update, quit and relaunch mcClippy once to re-register the hotkey.

> mcClippy 1.1.0 and later re-registers the global hotkey automatically on `NSWorkspace.didWakeNotification` and `sessionDidBecomeActiveNotification`, so the historical "shortcut stops working after the Mac has been on for days" bug is fixed. If you see this symptom on 1.1.0+, file an issue.

## Enter Restores Clipboard But Does Not Paste

- Open Settings → General.
- Enable "Paste selected item into the previous app on Enter."
- Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility).
- Confirm App Sandbox is disabled in the Release build (the published `.zip` already is).

## Accessibility Permission Still Shows Missing

This typically happens after an in-place update because the binary signature changed.

- Open System Settings → Privacy & Security → Accessibility.
- Remove mcClippy if it is already listed.
- Add `/Applications/mcClippy.app` again.
- Quit and relaunch mcClippy.

Alternatively, in Terminal: `tccutil reset Accessibility makmaj.mcClippy` then relaunch mcClippy; the system will re-prompt on the next auto-paste.

## Auto-Paste Lands in the Wrong App

mcClippy waits up to ~400 ms for the previously-frontmost app to actually become frontmost before posting `⌘V`. If you see paste landing in the wrong app, the target app may be slow to activate (heavy Electron apps, app being launched cold). Try once more — the second attempt usually catches focus.

## Extract & Paste as Text Returns Nothing

- The screenshot may contain only graphics, not recognizable text. The menu item changes to "No Text Found" when this happens.
- Confirm OCR is enabled in Settings → General → Text Extraction.
- Very low-contrast or stylized text may not be recognized. Try a higher-resolution screenshot.

## Exclusions Do Not Catch Every Copy

App exclusions are based on the frontmost app at polling time. If you copy and switch apps very quickly, macOS may not provide enough context for perfect attribution.

## Sensitive Items Are Hidden

This is expected. Click the eye button on a sensitive row to reveal it temporarily. Pasting works while the preview is hidden.

## History Does Not Include a Copied Item

Possible reasons:

- Monitoring is paused (the menu bar item will say "Resume Monitoring" when paused).
- Private mode is active (the menu bar item will say "Private Mode (Active)").
- The current app is excluded.
- The pasteboard is marked concealed/transient.
- The item exceeds the configured maximum item size.
- Encryption key creation failed.
