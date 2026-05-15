# mcClippy

Local-first, Win+V-style clipboard history for macOS. Lives in your menu bar, opens with a configurable shortcut, and pastes back into the app you were in.

<img width="770" height="984" alt="image" src="https://github.com/user-attachments/assets/3aa488b3-3990-48cf-a353-9ba07e434a06" />
<img width="723" height="753" alt="image" src="https://github.com/user-attachments/assets/66d2e99b-4c44-49f2-b6f9-08f85b624c92" />

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![License](https://img.shields.io/badge/license-MIT-green) ![Release](https://img.shields.io/github/v/release/PurpleRick/mcClippy)

## Features

- **Win+V-style floating panel** that appears near your cursor on `⌘⇧V` (rebindable)
- **Keyboard-first**: arrow keys move, Return pastes (and auto-pastes into the previous app), Esc closes
- **Filters**: All / Pinned / Text / Image / Link, plus full-text search across content, source app, and OCR'd image text
- **On-device OCR for images** — right-click any image in the panel and choose **Extract & Paste as Text** to recognize text with Apple's Vision framework. Runs locally on your Mac, no network. Results are cached on the item, so the second extraction is instant, and the extracted text feeds into the global search box
- **Encrypted at rest**: every captured blob is sealed with ChaChaPoly using a Keychain-stored 256-bit key (scoped to this Mac, only readable while unlocked)
- **Sensitive content masked by default** with an eye-toggle — passwords can be captured from anywhere and still paste while hidden. OCR'd text is run through the same detector, so screenshots of password manager UIs or `.env` files get the same blur treatment
- **Per-app exclusion list** so capture pauses while specific bundle IDs are frontmost
- **Configurable retention** for regular and pinned items. The default is Windows-like: keep history until the next reboot
- **Sleep/wake-resilient shortcut** — the global hotkey re-arms automatically on wake and session-active notifications, so it keeps working even after the Mac has been on for days
- **Reliable auto-paste** — waits up to ~400 ms for the target app to actually become frontmost before posting `⌘V`, and routes through the HID event tap so Electron / Chromium destinations don't silently drop the keystroke
- **Launch at login** (via `SMAppService`), pause / private-mode, clear-by-type controls
- **First-run onboarding** with the live keyboard shortcut surfaced

## Install

1. Download the latest `mcClippy-x.y.z.zip` from the [Releases page](https://github.com/PurpleRick/mcClippy/releases).
2. Unzip and drag `mcClippy.app` into `/Applications`.
3. **First launch only** — the build is ad-hoc signed, so macOS Gatekeeper will quarantine it. Pick one:
   - **Right-click → Open**, confirm in the dialog, OR
   - In Terminal: `xattr -dr com.apple.quarantine /Applications/mcClippy.app`
4. Press `⌘⇧V` anywhere to open the panel near your cursor.
5. For **auto-paste** into the previous app, approve mcClippy in System Settings → Privacy & Security → Accessibility when prompted.

> Developer ID notarization is planned for the next release cycle — once Apple Developer enrollment is set up, the quarantine step (`xattr -dr`) goes away.

**Requirements**: macOS 14.0 or later. Apple Silicon and Intel both supported.

## Keyboard

| Action | Shortcut |
|---|---|
| Open / close panel | `⌘⇧V` (rebindable in Settings → General) |
| Move selection | `↑` / `↓` |
| Paste selected (and close) | `Return` |
| Close panel | `Esc` |
| Paste as plain text | Right-click row → Paste as Text |
| Extract text from image | Right-click image row → Extract & Paste as Text |
| Pin / unpin | Click pin icon or right-click row |
| Reveal sensitive | Click eye icon on row |

## Privacy

- **100% local.** No network calls. No telemetry. No iCloud sync (yet). OCR runs on-device via Apple's Vision framework — image bytes never leave your Mac.
- **Encrypted at rest.** Captured content blobs are sealed with `ChaChaPoly`. The symmetric key lives in your login Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — only this Mac, only while unlocked.
- **Sensitive items never store plaintext previews.** Strings matching `password`, `api_key`, `token`, `bearer`, `private key`, `sk_*`, `pk_*`, or high-entropy base64 are flagged; the persisted preview is a placeholder, and the real preview is only re-derived from the decrypted blob at display time when you click the eye.
- **OCR results are sensitivity-checked.** When you extract text from an image, the result runs through the same detector. A screenshot of a `.env` file or password manager UI auto-flags as sensitive and gets the same blur treatment.
- **Passwords can be captured.** Password-manager sources and concealed / transient / auto-generated pasteboard markers are treated as sensitive signals, so their rows are masked by default but remain pasteable.
- **Until reboot is the default.** Regular and pinned item retention can be changed separately in Settings → General, but a clean/default install clears persisted history once per Mac reboot.
- **Exclusion list.** Add any bundle ID under Settings → Exclusions to suppress capture while it's frontmost.

A `PrivacyInfo.xcprivacy` manifest is bundled — see [`mcClippy/PrivacyInfo.xcprivacy`](mcClippy/PrivacyInfo.xcprivacy).

## Build from source

```bash
git clone https://github.com/PurpleRick/mcClippy.git
cd mcClippy
xcodebuild -project mcClippy.xcodeproj -scheme mcClippy -configuration Release build
```

Requires Xcode 16 or later. App Sandbox is currently disabled in the direct-distribution build so auto-paste can post `CGEvent`s without the sandbox-specific `kTCCServicePostEvent` flow; a sandboxed Mac App Store build using that TCC privilege is planned.

## Architecture

| Module | Responsibility |
|---|---|
| `mcClippyApp` | App entry, scenes, AppDelegate |
| `PasteHistoryPanelController` | Borderless floating `NSPanel` hosting the SwiftUI panel |
| `ContentView` | The panel UI — search, filters, list, keyboard handling, OCR dispatch |
| `PasteboardMonitor` | Change-count polling at app scope |
| `PasteboardSerializer` | Capture, restore, sensitive-aware preview derivation |
| `EncryptionService` | ChaChaPoly seal/open + Keychain-resident key |
| `OCRService` | Vision-based text extraction, concurrency-capped, dedup by item ID, 4096px downsample |
| `GlobalShortcutManager` | Carbon hot key with re-registration on `NSWorkspace.didWakeNotification` / `sessionDidBecomeActiveNotification` |
| `ShortcutStore` / `ShortcutRecorderView` | Configurable shortcut + record UI |
| `AutoPaster` / `AccessibilityHelper` | CGEvent `⌘V` posting with poll-for-active retry, HID event tap, Accessibility trust |
| `AppExclusionStore` | Per-bundle-ID denylist |
| `HistorySettings` / `OCRSettings` / `LaunchAtLoginSettings` | Persisted user settings via `UserDefaults` |
| `OnboardingController` | First-run welcome window |
| `Item` | SwiftData model (includes `ocrText` / `ocrCompletedAt`) |

Full details under [`mcClippy/Documentation/`](mcClippy/Documentation/).

## Releasing

Push a `v*.*.*` tag. GitHub Actions builds, ad-hoc signs, packages, and publishes to Releases.

```bash
git tag v1.1.0
git push origin v1.1.0
```

The workflow lives in [`.github/workflows/release.yml`](.github/workflows/release.yml) and has commented stubs for adding Developer ID signing + `notarytool` when paid Apple Developer enrollment is in place.

## License

MIT — see [LICENSE](LICENSE).
