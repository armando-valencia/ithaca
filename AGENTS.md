# Ithaca Agent Instructions

## Git Workflow

- Do not commit, push, merge, rebase, reset, or force-push unless the user explicitly asks.
- `project/repository-reliability-hardening` is the integration branch for the
  repository-reliability initiative. It is based on `develop` and will merge back
  into `develop` only after the initiative is complete.
- Create each independently deliverable task from the project branch, never from
  `develop` or another feature branch.
- Name feature branches `feature/ith-<task-number>`, where `ith` is the Ithaca
  project abbreviation and the task number is the tracking item (for example,
  `feature/ith-005`).
- Before starting a new feature after its predecessor has merged, run
  `scripts/start-feature.sh <task-number> <base-branch>`. The script
  fast-forwards the selected base branch from `origin` before creating the next
  feature branch. Use `project/repository-reliability-hardening` for initiative
  work and `develop` for one-off enhancements.
- After a feature is complete and the user authorizes the Git operations, provide
  a commit message and create a pull request from its feature branch into
  `project/repository-reliability-hardening` with `scripts/open-feature-pr.sh`.
- Do not merge feature branches into the project branch unless the user explicitly
  asks. Do not merge the project branch into `develop` until all initiative work
  is complete and the user explicitly asks.

## Engineering Standards

- Choose the simplest implementation that fully meets the requirements.
- Make architectural decisions for the long term. Do not use temporary stopgaps
  intended to be replaced later.
- Prefer clear structure and human-readable file, type, function, and variable
  names over explanatory comments.
- Do not add comments unless they communicate information that cannot be made
  clear through code structure and naming.
- When handing off a completed feature, provide a concise commit message suitable
  for that feature's changes.
