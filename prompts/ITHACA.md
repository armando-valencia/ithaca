You are building a macOS menu bar app called **Ithaca**.

Ithaca’s sole purpose is to let a developer instantly search local git repositories and open the selected repository in **Visual Studio Code**.

The app prioritizes speed, focus, and minimalism.

---

## Goals (v1)

- Extremely fast access via menu bar
- Instant search over hundreds of repos
- Open repos in VS Code with minimal friction
- Clean, distraction-free UI

Non-goals:

- No global hotkey
- No git branch/status
- No tags, tech detection, or repo metadata beyond name/path/recents
- No editor support other than VS Code
- No networking or analytics

---

## Platform & Tech

- macOS 13+
- Swift 5
- SwiftUI + AppKit where required
- No third-party dependencies

---

## App Behavior

- Runs as a menu bar app (status bar only, no Dock icon if feasible)
- Clicking the status bar icon toggles a popover
- Popover size ~420px wide, max ~520px tall, scrollable
- Popover closes on Esc
- Search field auto-focuses on popover open

---

## Workspace Roots

- User can configure **one or more workspace root directories**
- Roots are chosen via NSOpenPanel (directories only)
- Persist roots in UserDefaults as absolute path strings
- If no roots are configured:
  - Show setup UI in the popover
  - Allow adding/removing roots
  - Provide a “Scan Repositories” action
- Once roots exist, show main UI (Search + Recents)

---

## Repo Definition

- A repo is a directory containing a `.git` directory
- Scan recursively under all workspace roots
- Ignore directories named:
  `node_modules`, `.venv`, `dist`, `build`, `.tox`, `.pytest_cache`,
  `.mypy_cache`, `.next`, `target`, `.gradle`

---

## Persistence

- Persist repo index and recents to:
  `~/Library/Application Support/Ithaca/index.json`
- Write atomically
- Load cached index immediately on startup
- Perform background rescan after launch if roots exist

Repo model:

- `id: String` (stable hash of full path)
- `name: String`
- `path: String`
- `lastOpened: Date?`

Workspace roots:

- Stored in UserDefaults (not in index.json)

---

## Search

- Case-insensitive
- Match priority:
  1. Prefix match on repo name
  2. Substring match on repo name
  3. Fuzzy match (query characters appear in order)
- Exclude non-matching repos
- Sort by:
  1. Match score descending
  2. lastOpened descending
  3. name ascending

---

## Recents

- Show when search query is empty
- Display up to 12 most recently opened repos
- Opening a repo updates its `lastOpened`

---

## Opening in VS Code (ONLY)

- Enter opens selected repo
- Attempt:
  1. `code <path>`
  2. `open -a "Visual Studio Code" <path>`
- Run asynchronously
- If both fail, show a concise inline error message

---

## Keyboard Controls

- Up / Down arrows: move selection
- Enter: open repo
- Esc: close popover

---

## UI Copy

- App name: Ithaca
- Search placeholder: “Search repositories…”
- Section header: “Recent”

---

## Deliverables

- Complete Swift / SwiftUI code
- Clear file structure
- README section describing:
  - How to build/run in Xcode
  - Where index.json is stored
  - Startup scanning behavior

---

## Skill: frontend-design

You have access to a reusable skill called **frontend-design**.

### Purpose

Ensure the UI is intuitive, minimal, human-designed, and avoids generic or “AI-looking” interfaces.

### Principles

When applying frontend-design:

- Prefer clarity over cleverness
- Reduce visual noise aggressively
- Use native macOS patterns and spacing
- Avoid unnecessary UI chrome, icons, borders, and labels
- Favor alignment, whitespace, and hierarchy over decoration
- UI copy should be minimal and neutral
- If unsure, remove UI rather than add it

### Constraints

- Do not invent visual themes or branding elements
- Do not add animations unless they improve clarity
- Do not introduce UI elements not explicitly required by the product scope

### When to Apply

- Any time UI layout, structure, spacing, or copy is being designed or adjusted
- Especially when implementing:
  - RootView
  - Setup UI
  - Search list
  - Recents section

Skills live in a directory called `prompts/skills` at the root of the repo.

---

## Skill Application Rule

When working on any UI-related code or decisions:

- Actively apply the **frontend-design** skill.
- If an agent produces UI code, it must be reviewed through the frontend-design lens before finalizing.
- If there is tension between feature completeness and UI simplicity, prioritize simplicity.

---

## Agent Registry

You may internally delegate to the following agents. Each agent has strict scope boundaries. Do not expand scope beyond v1.

Agents:

- menu-bar-shell
- repo-indexer
- search-ranker
- recents-manager
- vscode-opener

Recommended build order:

1. menu-bar-shell
2. repo-indexer
3. search-ranker
4. vscode-opener
5. recents-manager

All agents must coordinate through a shared `Repo` model and a single store layer.

Agents live in a directory called `prompts/agents` at the root of the repo.

---

## UI Quality Gate

Before finalizing the implementation:

- Review all SwiftUI views through the frontend-design skill.
- Remove any UI elements that are not strictly necessary.
- Prefer native macOS controls and default styling unless deviation clearly improves clarity.
