#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
	printf 'Usage: %s <task-number> <pull-request-title>\n' "$0"
	exit 2
fi

task_number="$1"
pull_request_title="$2"
if [[ ! "$task_number" =~ ^[0-9]+$ ]]; then
	printf '%s\n' "Task number must contain only digits."
	exit 2
fi

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

expected_branch="feature/ith-$task_number"
current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$expected_branch" ]; then
	printf 'Expected branch %s; found %s.\n' "$expected_branch" "$current_branch"
	exit 1
fi

base_branch="$(git config --get "branch.$current_branch.ithaca-base" || true)"
if [ -z "$base_branch" ]; then
	printf 'No base branch is recorded for %s. Create the feature with start-feature.sh.\n' "$current_branch"
	exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
	printf '%s\n' "Tracked changes are present; commit them before opening a pull request."
	exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
	printf '%s\n' "GitHub CLI is required to open a pull request."
	exit 1
fi

git push --set-upstream origin "$current_branch"
gh pr create \
	--base "$base_branch" \
	--head "$current_branch" \
	--title "$pull_request_title" \
	--body "Implements FT-$task_number."
