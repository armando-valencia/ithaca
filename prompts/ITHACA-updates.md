You are updating the macOS menu bar app **Ithaca**.

This prompt builds on `prompts/ITHACA.md` and keeps all hard constraints **except** where explicitly overridden below.

---

## Scope Updates (v2 Menu Bar Enhancements)

New capabilities to add:
- Repo metadata (lightweight, local-only, cached)
- Multiple workspace roots (already present; improve UX + resilience)
- Pinned repos (persistent, user-controlled)
- Open targets (multiple apps, per-repo default)
- Global shortcut to toggle the popover (opt-in)

Explicit overrides to v1 non-goals:
- Global hotkey is now allowed (opt-in and user configurable).
- Metadata beyond name/path/recents is now allowed, but must be minimal and local-only.
- Editor support expands beyond VS Code via Open Targets.

Everything else from `prompts/ITHACA.md` remains in force:
- Menu bar only, no Dock icon if feasible
- Speed, focus, minimal UI
- macOS 13+, Swift 5, SwiftUI + AppKit
- No third-party dependencies
- No networking or analytics

---

## Agents and Skills (Hard Requirement)

Use the existing agents in this order unless a step is already done:
1) menu-bar-shell
2) repo-indexer
3) search-ranker
4) vscode-opener (extend to multi-target opener)
5) recents-manager

All agents must coordinate through the shared `Repo` model and a single store layer.

UI changes must be reviewed and shaped using the **frontend-design** skill found at `prompts/skills/frontend-design.md`.

---

## Feature Requirements

### Metadata (Minimal)
- Store only lightweight, local metadata:
  - `lastOpened` (existing)
  - `isPinned` (new)
  - `rootName` or `rootPath` label for display
  - Optional: `lastModified` from filesystem attributes
- No git branch/status or network calls.
- Metadata must be cached in `index.json` alongside repos.

### Multiple Roots (UX/Robustness)
- Keep multi-root support; improve UX for managing roots.
- Allow adding/removing roots without blocking scanning.
- Show root label in repo rows (subtle secondary text).

### Pins
- User can pin/unpin repos.
- Pinned repos appear above recents and search results.
- Pins persist across restarts in `index.json` or UserDefaults (choose one; be consistent).

### Open Targets
- User can choose a default app to open each repo.
- Provide a global default and per-repo overrides.
- Minimum target set:
  - Visual Studio Code
  - Xcode
  - IntelliJ IDEA
  - Finder (reveal in Finder)
  - Terminal (open in default terminal)
- Keep original VS Code behavior as the default.
- Use system `open` where possible; avoid dependencies.

### Global Shortcut (Opt-In)
- Add a configurable global hotkey to toggle the popover.
- Must be opt-in and stored locally.
- Provide a simple UI affordance to set/clear the shortcut.

---

## UI/UX

- Preserve the current minimal, focused popover.
- Add new UI controls only where necessary (pins, open targets, shortcut settings).
- Favor native macOS patterns and default controls.
- Avoid extra labels, icons, or chrome unless they clarify behavior.

---

## Data & Persistence

- Continue using `~/Library/Application Support/Ithaca/index.json`.
- Write atomically.
- Load cached index immediately; rescan in background if roots exist.
- Ensure pinned state and open targets persist consistently.

---

## Deliverables

- Updated Swift/SwiftUI code with the new features.
- Updated README:
  - How to configure roots, pins, open targets, and hotkey
  - index.json location and fields
  - Startup scanning behavior

