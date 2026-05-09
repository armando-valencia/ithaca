#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
	printf 'Usage: %s <task-number> <base-branch>\n' "$0"
	exit 2
fi

task_number="$1"
base_branch="$2"
if [[ ! "$task_number" =~ ^[0-9]+$ ]]; then
	printf '%s\n' "Task number must contain only digits."
	exit 2
fi

feature_branch="feature/ith-$task_number"
repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

if ! git diff --quiet || ! git diff --cached --quiet; then
	printf '%s\n' "Tracked changes are present; commit or stash them before starting a feature."
	exit 1
fi

if git show-ref --verify --quiet "refs/heads/$feature_branch"; then
	printf 'Branch already exists: %s\n' "$feature_branch"
	exit 1
fi

git switch "$base_branch"
git pull --ff-only origin "$base_branch"
git switch --create "$feature_branch"
git config "branch.$feature_branch.ithaca-base" "$base_branch"

printf 'Started %s from the latest %s.\n' "$feature_branch" "$base_branch"
