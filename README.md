# mcClippy

Local-first, Win+V-style clipboard history for macOS. Lives in your menu bar, opens with a configurable shortcut, and pastes back into the app you were in.
<img width="770" height="984" alt="image" src="https://github.com/user-attachments/assets/3aa488b3-3990-48cf-a353-9ba07e434a06" />

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Win+V-style floating panel** that appears near your cursor on `⌘⇧V` (rebindable)
- **Keyboard-first**: arrow keys move, Return pastes (and auto-pastes into the previous app), Esc closes
- **Filters**: All / Pinned / Text / Image / Link, plus full-text search across content + source app
- **Encrypted at rest**: every captured blob is sealed with ChaChaPoly using a Keychain-stored 256-bit key (scoped to this Mac, only readable while unlocked)
- **Sensitive content masked by default** with an eye-toggle — passwords can be captured from anywhere and still paste while hidden
- **Per-app exclusion list** so capture pauses while specific bundle IDs are frontmost
- **Configurable retention** for regular and pinned items. The default is Windows-like: keep history until the next reboot.
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

**Requirements**: macOS 14.0 or later. Apple Silicon and Intel both supported.

## Keyboard

| Action | Shortcut |
|---|---|
| Open / close panel | `⌘⇧V` (rebindable in Settings → General) |
| Move selection | `↑` / `↓` |
| Paste selected (and close) | `Return` |
| Close panel | `Esc` |
| Paste as plain text | Right-click row → Paste as Text |
| Pin / unpin | Click pin icon or right-click row |
| Reveal sensitive | Click eye icon on row |

## Privacy

- **100% local.** No network calls. No telemetry. No iCloud sync (yet).
- **Encrypted at rest.** Captured content blobs are sealed with `ChaChaPoly`. The symmetric key lives in your login Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — only this Mac, only while unlocked.
- **Sensitive items never store plaintext previews.** Strings matching `password`, `api_key`, `token`, `bearer`, `private key`, `sk_*`, `pk_*`, or high-entropy base64 are flagged; the persisted preview is a placeholder, and the real preview is only re-derived from the decrypted blob at display time when you click the eye.
- **Passwords can be captured.** Password-manager sources and concealed / transient / auto-generated pasteboard markers are treated as sensitive signals, so their rows are masked by default but remain pasteable.
- **Until reboot is the default.** Regular and pinned item retention can be changed separately in Settings → General, but a clean/default install clears persisted history once per Mac reboot.
- **Exclusion list.** Add any bundle ID under Settings → Exclusions to suppress capture while it's frontmost.

## Build from source

```bash
git clone https://github.com/PurpleRick/mcClippy.git
cd mcClippy
xcodebuild -project mcClippy.xcodeproj -scheme mcClippy -configuration Release build
```

Requires Xcode 15 or later. App Sandbox is disabled so auto-paste can post `CGEvent`s; if you re-enable it you'll lose auto-paste but everything else still works.

## Architecture

| Module | Responsibility |
|---|---|
| `mcClippyApp` | App entry, scenes, AppDelegate |
| `PasteHistoryPanelController` | Borderless floating `NSPanel` hosting the SwiftUI panel |
| `ContentView` | The panel UI — search, filters, list, keyboard handling |
| `PasteboardMonitor` | Change-count polling at app scope |
| `PasteboardSerializer` | Capture, restore, sensitive-aware preview derivation |
| `EncryptionService` | ChaChaPoly seal/open + Keychain-resident key |
| `GlobalShortcutManager` | Carbon hot key with live re-registration |
| `ShortcutStore` / `ShortcutRecorderView` | Configurable shortcut + record UI |
| `AutoPaster` / `AccessibilityHelper` | CGEvent `⌘V` posting, Accessibility trust |
| `AppExclusionStore` | Per-bundle-ID denylist |
| `HistorySettings` / `LaunchAtLoginSettings` | Retention + login-item via `SMAppService` |
| `OnboardingController` | First-run welcome window |
| `Item` | SwiftData model |

Full details under [`mcClippy/Documentation/`](mcClippy/Documentation/).

## Releasing

Push a `v*.*.*` tag. GitHub Actions builds, ad-hoc signs, packages, and publishes to Releases.

```bash
git tag v1.0.1
git push origin v1.0.1
```

The workflow lives in [`.github/workflows/release.yml`](.github/workflows/release.yml) and has commented stubs for adding Developer ID signing + notarytool when you get a paid Apple Developer account.

## License

MIT — see [LICENSE](LICENSE).
