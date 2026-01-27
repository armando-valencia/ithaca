# Ithaca

Ithaca is a macOS menu bar app for instantly searching local git repositories and opening them in Visual Studio Code.

## Build & Run

- Open `Ithaca/Ithaca.xcodeproj` in Xcode.
- Select the `Ithaca` scheme.
- Run the app (macOS 13+).

  > From Xcode, you can just run cmd+R to build and run thr project.

## Index Storage

The repo index is stored at:

- `~/Library/Application Support/Ithaca/index.json`

## Startup Scanning Behavior

- The app loads the cached index immediately at launch.
- If workspace roots are configured, a background rescan starts after launch.
- Scans are recursive and ignore common build/cache directories.
