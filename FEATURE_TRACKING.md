# Ithaca Feature Tracking

Audit date: 2026-08-02  
Scope: static review of the macOS application, project configuration, README, and
agent prompts. No application behavior was changed and no build was run.

## Bugs

### FT-001 — App cannot run on the documented macOS versions

- **Priority:** P0
- **Evidence:** The README and `prompts/agents/menu-bar-shell.md` state macOS 13+
  support, while both Debug and Release set `MACOSX_DEPLOYMENT_TARGET = 26.2` in
  `Ithaca/Ithaca.xcodeproj/project.pbxproj`.
- **Impact:** The distributed app excludes every macOS 13–15 user, contradicting
  the stated compatibility promise.
- **Suggested resolution:** Choose the intended minimum macOS release, set it
  consistently for every configuration, and update the README and prompts.
- **Acceptance criteria:** A clean build installs and launches on the documented
  minimum macOS version.

### FT-002 — Repositories under a bookmark-resolved root cannot be opened

- **Priority:** P1
- **Evidence:** The scanner resolves a stale/moved security-scoped bookmark and
  indexes with the resolved path (`RepoStore.scan`, lines 296–301), but opening
  authorizes paths only against the original strings in `workspaceRoots`
  (`RepoStore.isPathAllowed`, lines 134–142). A moved root therefore scans, but
  every discovered repository fails the authorization check in `ContentView.swift`
  lines 452–456.
- **Impact:** Moving or renaming an authorized workspace can leave repositories
  visible but impossible to open.
- **Suggested resolution:** Persist and compare canonical resolved root URLs (or
  authorize against the active bookmark-resolved URL) throughout scanning and
  opening.
- **Acceptance criteria:** After moving a configured root, a rescan finds its
  repositories and all open targets succeed.

### FT-003 — Git worktree branches are never displayed

- **Priority:** P1
- **Evidence:** The repository scan treats a `.git` file as a repository marker
  (`RepoStore.scan`, lines 343–356), which is how Git worktrees are represented.
  `GitBranchProvider` then rejects an absolute `gitdir:` unless it resides beneath
  the worktree directory (`GitBranchProvider.swift` lines 30–39). Git normally
  places worktree metadata in the parent repository’s `.git/worktrees` directory,
  outside the worktree.
- **Impact:** A supported, discovered Git worktree permanently shows no branch.
- **Suggested resolution:** Safely resolve valid absolute and relative `gitdir:`
  targets, then verify the target is a Git directory instead of imposing a
  worktree-local path restriction.
- **Acceptance criteria:** A linked worktree shows its checked-out branch, while
  malformed `.git` files remain rejected.

### FT-004 — Branch labels become stale after changing branches

- **Priority:** P1
- **Evidence:** Branches are cached by repository ID in `branchByID`
  (`ContentView.swift` line 20). `updateBranchesIfNeeded` fetches only IDs with no
  cached value (lines 475–489); no event, rescan, or reopen invalidates that
  cache.
- **Impact:** The branch shown in a long-running app can differ from the active
  Git branch.
- **Suggested resolution:** Refresh branch data when the popover opens and after a
  rescan, with cancellation/deduplication for concurrent lookups.
- **Acceptance criteria:** Switching branches while Ithaca is running is reflected
  the next time its UI is opened.

### FT-005 — A child process can hang repository opening indefinitely

- **Priority:** P1
- **Evidence:** `ProcessRunner` waits until process termination before reading
  either stdout or stderr (`VSCodeOpener.swift` lines 103–112). If a launched
  program fills either pipe buffer, it blocks waiting for the buffer to drain and
  never terminates; the continuation never resumes.
- **Impact:** Opening a repository can remain pending forever for a noisy child
  process or an unexpected command implementation.
- **Suggested resolution:** Drain output concurrently, redirect unused output, and
  add a bounded timeout/cancellation strategy.
- **Acceptance criteria:** A subprocess emitting more than a pipe buffer on either
  stream completes without hanging the UI task.

### FT-006 — Global shortcut failures are silently reported as enabled

- **Priority:** P1
- **Evidence:** `RegisterEventHotKey` returns an `OSStatus`, but
  `GlobalHotkeyManager.register` discards it (`GlobalHotkeyManager.swift` lines
  55–65). The UI always renders the configured shortcut from `HotkeyStore`
  (`ContentView.swift` lines 225–254).
- **Impact:** If another app owns the shortcut or registration otherwise fails,
  users see the shortcut as active but cannot invoke Ithaca.
- **Suggested resolution:** Surface registration state and failure reason, and
  offer a configurable fallback shortcut.
- **Acceptance criteria:** A conflicting shortcut is visibly reported and never
  presented as enabled.

## Stale Code And Cleanup

### FT-007 — Remove unused repository metadata and mutation APIs

- **Priority:** P2
- **Evidence:** `Repo.rootPath` and `Repo.rootName` are populated and persisted
  but have no reads outside `Repo.swift`. `RepoStore.setPinned` and
  `RepoStore.setOpenTarget` likewise have no callers.
- **Impact:** The stored index carries unused fields and the public store API has
  misleading dead surface area.
- **Suggested resolution:** Remove the unused fields and methods, or implement
  the product behavior that needs them with tests and migration compatibility.

### FT-008 — Simplify unused process output and imports

- **Priority:** P3
- **Evidence:** `ProcessResult.stdout` and `.stderr` are populated but never read.
  `VSCodeOpener.swift` imports `AppKit` without using it.
- **Impact:** The subprocess abstraction does extra work and obscures the actual
  result contract.
- **Suggested resolution:** Either consume output in actionable error reporting or
  remove its capture and the unused import.

### FT-009 — Repair stale agent-prompt guidance

- **Priority:** P3
- **Evidence:** `prompts/agents/menu-bar-shell.md` points to a non-existent
  `promots/skills` directory and its macOS 13+ requirement conflicts with the
  project deployment target. `prompts/agents/repo-indexer.md` says a repository
  requires a `.git` directory, whereas the implementation also indexes worktrees
  with a `.git` file.
- **Impact:** Future implementation work is guided by contradictory or invalid
  instructions.
- **Suggested resolution:** Update prompt paths and align requirements with the
  supported product behavior.

## Necessary Improvements And Feature Work

### FT-010 — Add automated tests and an Xcode test target

- **Priority:** P1
- **Evidence:** The project defines only the application target and the repository
  contains no test sources or test plan.
- **Impact:** Core behavior (ranking, cache decoding, scanning, path
  authorization, worktrees, and process handling) can regress unnoticed.
- **Suggested resolution:** Add unit tests first for `SearchRanker`, `Repo`, and
  a filesystem-injected scanner; then add integration coverage for security
  bookmarks and all open targets.
- **Acceptance criteria:** Tests cover every P1 defect above and run in CI.

### FT-011 — Report scan and persistence failures to users

- **Priority:** P2
- **Evidence:** Bookmark creation/refresh, index decoding, directory enumeration,
  and index saving all use silent failure paths (`RepoStore.swift` lines 215–279
  and 328–333).
- **Impact:** Permission loss, corrupt cache data, or inaccessible directories are
  indistinguishable from an empty workspace; users have no recovery guidance.
- **Suggested resolution:** Expose scan status, per-root failures, and a recovery
  action while retaining non-blocking startup behavior.
- **Acceptance criteria:** Revoked access and a corrupt index produce a visible,
  actionable message and do not crash the app.

### FT-012 — Define repository-discovery coverage and validate Git markers

- **Priority:** P2
- **Evidence:** Enumeration uses `.skipsHiddenFiles` (`RepoStore.swift` line 331),
  so repositories beneath hidden directories are excluded. Conversely, discovery
  accepts any file or directory named `.git` without validating it as Git metadata
  (lines 314–356).
- **Impact:** Valid repositories can be missed, while non-repositories can appear
  in results.
- **Suggested resolution:** Decide whether hidden directory traversal is intended;
  validate `.git` directories and `gitdir:` files before indexing; document the
  resulting policy, including bare repositories if they should be supported.
- **Acceptance criteria:** Discovery behavior is documented and tested for normal
  repositories, linked worktrees, hidden paths, malformed markers, and bare repos.

### FT-013 — Make global shortcut configuration a complete user feature

- **Priority:** P2
- **Evidence:** `HotkeyStore` can persist a custom or nil shortcut, but no UI
  invokes `setHotkey`; the interface only displays a hard-coded instruction for
  `⌃⌥⌘I` (`ContentView.swift` lines 225–254).
- **Impact:** Users cannot change, disable, or recover from a conflicting global
  shortcut.
- **Suggested resolution:** Add a shortcut recorder, disable/reset controls, and
  conflict/error feedback tied to actual registration status.
- **Acceptance criteria:** Users can set, clear, and restore a shortcut, with the
  resulting registration state shown accurately.

### FT-014 — Add a release-quality distribution workflow

- **Priority:** P2
- **Evidence:** The README documents manual handling for unsigned builds, but the
  project has no visible test target or release automation configuration.
- **Impact:** Releases lack repeatable build, test, signing, notarization, and
  artifact verification steps.
- **Suggested resolution:** Document a reproducible release checklist and add CI
  for build/tests; add signing and notarization once distribution requires it.
- **Acceptance criteria:** A tagged release can be built and verified from a clean
  environment using documented steps.
