# Ithaca

Ithaca is a macOS menu bar app for finding local Git repositories and opening
them quickly.

## What It Does

- Searches configured workspace directories for repositories.
- Opens a repository in Visual Studio Code, Xcode, or Finder.
- Keeps pinned repositories and recent opens close at hand.
- Shows the checked-out branch for normal repositories and linked worktrees.
- Offers a configurable global shortcut (default: `⌃⌥⌘I`).

## Requirements

- macOS 26.2 or later
- Xcode 26.2 or later to build from source

## Use Ithaca

1. Run the app and select its sailboat icon in the menu bar.
2. Choose **Add Directory…** and select one or more workspace roots.
3. Search by repository name, use the arrow keys to select a result, and press
   **Enter** to open it.
4. Use the settings button to change the default open target, manage directories,
   show or hide branches, or record a different global shortcut.

## Develop

Open `Ithaca/Ithaca.xcodeproj` in Xcode, select the `Ithaca` scheme, and run it.

Run the test suite from the command line with:

```sh
xcodebuild -project Ithaca/Ithaca.xcodeproj -scheme Ithaca test
```

<details>
<summary>Repository discovery and saved data</summary>

- Ithaca loads its cache at launch and rescans configured roots in the background.
- Scans are recursive, skip hidden descendant directories, and skip common
  generated directories such as `node_modules`, `build`, and `dist`.
- Normal repositories and linked worktrees are supported; bare repositories are
  not indexed.
- The cache lives at `~/Library/Application Support/Ithaca/index.json`.
- If a directory permission or cache error occurs, Ithaca shows recovery actions
  to rescan, update directories, or reset the saved index.

</details>

<details>
<summary>Releases</summary>

Follow the [release checklist](docs/RELEASE.md) for build, verification, signing,
notarization, and distribution steps.

</details>
