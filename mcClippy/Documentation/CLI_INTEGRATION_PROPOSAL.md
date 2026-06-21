# Proposal: mcClippy for the CLI and AI agents

Status: **proposal / not implemented.** Captures the design and security model for exposing clipboard history to terminal tools and AI agents (e.g. Claude Code). Nothing here ships until the direction — especially the security posture — is signed off.

## Motivation

Two gaps make this worth doing:

- **Getting clipboard content into CLI AI tools is painful and platform-fragmented.** In Claude Code, `Cmd+V` is swallowed by the terminal so image paste needs `Ctrl+V`; Windows/WSL paste often fails because images arrive as BMP; there are open feature requests for "smart paste" of text/images/files (`anthropics/claude-code` issues #27564, #12644, #26679).
- **No clipboard manager exposes its searchable *history* to the command line or to an agent.** `pbcopy`/`pbpaste` only see the *current* clipboard. mcClippy already has an encrypted, searchable, OCR-indexed history — it is uniquely positioned to fill this gap.

## Design

The running app opens a **Unix-domain socket** in its support directory (user-only `0600`, no network surface). The app stays the single owner of the store and the encryption key, so decryption happens in-process — no duplicated crypto, no second DB writer.

A small `mcclippy` CLI connects and speaks a line protocol:

| Command | Behavior | Value |
| --- | --- | --- |
| `mcclippy list [--type text\|image] [-n N]` | recent history as a table or `--json` | inspect history without the GUI |
| `mcclippy get <id>` | print item text to stdout | `pbpaste` for *history* — pipe anywhere |
| `mcclippy copy <id>` | load a history item onto the live clipboard, images normalized to PNG | makes `Ctrl+V` into Claude Code work, sidesteps the BMP failure |
| `mcclippy file <id>` | materialize an image to a temp file, print path | drag into the terminal or pass as a file arg |
| `mcclippy search <q>` | full-text search including OCR'd screenshots | "find that key I copied yesterday" |

### AI-centric layer (MCP)

A thin `mcclippy-mcp` stdio shim proxies to the same socket and exposes tools (`search_clipboard`, `get_clipboard_item`, `list_recent`). Registered with `claude mcp add mcclippy -- mcclippy-mcp`, it lets an agent use clipboard history — including text OCR'd from screenshots — as context. This is the differentiated capability: history + on-device OCR as agent context.

## Security model

mcClippy's whole purpose is that secrets never sit in plaintext on disk, so any programmatic read channel must be conservative:

- **Opt-in, default off.** A Settings toggle; the socket is not created unless enabled.
- **Sensitive items masked by default.** The CLI/MCP returns the placeholder, never the secret, unless both an explicit `--reveal` flag and a separate "allow revealing secrets over CLI" sub-option are set.
- **No network surface.** Unix socket only, `0600`, in the user's container.
- **Audited.** Every CLI/MCP access is logged via `os.Logger` (the existing `Log` categories).
- **Documented tradeoff.** Enabling this lets any local process for the user request history; that widens the attack surface, which is why it is off by default and secrets stay masked.

## Phased plan

1. **Phase 1** — in-app Unix-socket command server (behind the toggle) + `mcclippy` client (`list/get/copy/file/search`). Delivers terminal wins immediately, including the Claude Code `Ctrl+V`/PNG fix.
2. **Phase 2** — `mcclippy-mcp` stdio shim for Claude Code and other MCP clients.
3. **Phase 3** (optional) — a "copy for agent / send to terminal" action in the panel UI.

## References

- anthropics/claude-code issues #27564, #12644, #26679 (clipboard/image paste)
- Maccy (`p0deje/Maccy`) — exemplifies the history-but-no-CLI gap
- `pbcopy`/`pbpaste` (macOS) — current CLI clipboard ceiling
