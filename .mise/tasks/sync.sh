#!/usr/bin/env bash
#MISE description="Fetch origin and rebase the current worktree onto the remote default branch"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/git.sh"

meb_config_validate

# Determine the directory from which `mise run` was invoked.
# mise sets MISE_ORIGINAL_CWD before changing to the project root.
invoke_dir="${MISE_ORIGINAL_CWD:-$PWD}"

# Find which worktree contains the invocation directory
current_branch=""
current_path=""
while IFS=$'\t' read -r branch path _dirty; do
  case "$invoke_dir" in
    "$path"|"$path"/*)
      current_branch="$branch"
      current_path="$path"
      break
      ;;
  esac
done < <(meb_list_worktrees)

if [[ -z "$current_branch" ]]; then
  echo "error: not inside a known worktree (invoked from: $invoke_dir)" >&2
  echo "       Run this command from within a worktree directory." >&2
  exit 1
fi

default_branch=$(meb_default_branch)

echo "Fetching from origin..."
meb_git fetch origin

echo "Rebasing '$current_branch' onto 'origin/$default_branch'..."
git -C "$current_path" rebase "origin/$default_branch"

echo "Done."
