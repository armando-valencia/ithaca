You are improving the UI/UX of the macOS menu bar app **Ithaca**.

This prompt is scoped to UI/UX polish only. All functionality should remain intact and minimal.

---

## Hard Constraints

- Preserve Ithaca’s minimal, fast menu-bar workflow.
- Use SwiftUI + AppKit only, no dependencies.
- Avoid heavy UI chrome, heavy theming, or branding.
- Keep the UI native to macOS. No custom color themes.
- Respect `prompts/ITHACA.md` and apply the **frontend-design** skill.

---

## UX Goals (High-Level)

- Make the app feel tighter, calmer, and more intentional without adding bloat.
- Improve scanability of the repo list.
- Make keyboard usage feel discoverable but unobtrusive.
- Keep the settings minimal and clear.

---

## Specific Improvements to Implement

### Header + Search
- Align the search field and open-target menu visually (consistent height, baseline).
- Add a faint inline hint under the search field:
  - Text: `↑↓ to navigate · Enter to open`
  - Only visible until the user interacts (typing or navigation).
  - Fade out after first interaction.

### Shortcut Display
- Display the shortcut as a small mono-styled pill:
  - Example: `⌃⌥⌘I`
- Keep a small info icon next to it that shows the tooltip/popover:
  - “Use ⌃⌥⌘I (letter I, not lowercase L).”

### Repo List Rows
- Use a consistent row height.
- Path line should be slightly dimmer than title.
- Branch text should be a subtly lighter gray than the path.
- Selection highlight should be subtle with a soft tint + thin outline.
- On hover, show a tiny right-aligned `↗` / arrow hint to indicate click opens.

### Sections
- Replace plain section headers (“Pinned”, “Recent”) with a subtle label + divider line.
- Use tight spacing to avoid visual noise.

### Empty State
- Replace the multi-line empty state with a single inline row:
  - `No matches.` + `Rescan` + `Directories…` on the same line.

### Settings Popover
- Replace the “Roots…” link with a gear icon.
- Settings popover should include:
  - “Show branches” toggle
  - “Directories” list with remove buttons
  - “Add Directory…” + “Rescan” actions
- Make all settings text consistent (use small caption text and secondary color).
- Directory paths should be rendered in subtle pill/badge backgrounds for readability.

### Flow Improvement
- After choosing a directory, automatically return to the main search view (don’t leave the user in setup).

---

## Notes

- Keep everything visually lightweight.
- Avoid adding new icons/labels unless they improve clarity.
- Do not introduce non-native styling or custom fonts.

