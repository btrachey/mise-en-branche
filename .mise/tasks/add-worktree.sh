#!/usr/bin/env bash
#MISE description="Create a new worktree (branch, issue, or interactive picker)"
#USAGE flag "--branch <branch>" help="Use or create branch by name"
#USAGE flag "--gh <number>" help="Resolve GitHub issue number to branch"
#USAGE flag "--linear <id>" help="Resolve Linear issue ID to branch"
#USAGE flag "--name <name>" help="Create new branch from free-form name"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/git.sh"
. "$SCRIPT_DIR/lib/tracker.sh"
. "$SCRIPT_DIR/lib/terminal.sh"

meb_config_validate

branch=""

if [[ -n "${usage_gh:-}" ]]; then
  branch=$(MEB_TRACKER=github meb_issue_to_branch "$usage_gh")
elif [[ -n "${usage_linear:-}" ]]; then
  branch=$(MEB_TRACKER=linear meb_issue_to_branch "$usage_linear")
elif [[ -n "${usage_branch:-}" ]]; then
  branch="$usage_branch"
elif [[ -n "${usage_name:-}" ]]; then
  branch=$(meb_slugify "$usage_name")
fi

# Interactive mode: pick from issue tracker
if [[ -z "$branch" ]]; then
  issues=$(meb_issue_list)
  if [[ -z "$issues" ]]; then
    echo "error: no open issues found" >&2
    exit 1
  fi

  selected=$(echo "$issues" | gum choose --header "Select an issue:")
  if [[ -z "$selected" ]]; then
    echo "Aborted." >&2
    exit 0
  fi

  issue_id=$(echo "$selected" | awk -F'\t' '{ print $1 }')
  branch=$(meb_issue_to_branch "$issue_id")
fi

# Check if worktree already exists
if meb_worktree_exists "$branch"; then
  existing_path=$(meb_worktree_path_for_branch "$branch")
  echo "Worktree for '$branch' already exists at: $existing_path"
  meb_open_window "$existing_path" "$branch"
  exit 0
fi

# Create the worktree
dir="${MEB_WORKTREE_PREFIX:-}${branch}"

# Determine if branch already exists in the remote
if meb_git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
  echo "Creating worktree for existing branch '$branch'..."
  meb_git worktree add "../${dir}" "$branch"
else
  echo "Creating worktree with new branch '$branch'..."
  default_branch=$(meb_default_branch)
  meb_git worktree add -b "$branch" "../${dir}" "$default_branch"
fi

worktree_path="$(pwd)/${dir}"
echo "Worktree created at: $worktree_path"

meb_open_window "$worktree_path" "$branch"
