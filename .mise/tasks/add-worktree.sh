#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/git.sh"
. "$SCRIPT_DIR/lib/tracker.sh"
. "$SCRIPT_DIR/lib/terminal.sh"

meb_config_validate

usage() {
  cat >&2 <<EOF
Usage: mise run add-worktree [OPTIONS]

Options:
  (none)          Interactive issue picker
  --branch <n>    Use or create branch by name
  --gh <number>   Resolve GitHub issue number to branch
  --linear <id>   Resolve Linear issue ID to branch
  --name <n>      Create new branch from free-form name

EOF
  exit 1
}

branch=""
mode=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      [[ $# -ge 2 ]] || { echo "error: --branch requires an argument" >&2; exit 1; }
      branch="$2"
      mode="branch"
      shift 2
      ;;
    --gh)
      [[ $# -ge 2 ]] || { echo "error: --gh requires an argument" >&2; exit 1; }
      branch=$(MEB_TRACKER=github meb_issue_to_branch "$2")
      mode="branch"
      shift 2
      ;;
    --linear)
      [[ $# -ge 2 ]] || { echo "error: --linear requires an argument" >&2; exit 1; }
      branch=$(MEB_TRACKER=linear meb_issue_to_branch "$2")
      mode="branch"
      shift 2
      ;;
    --name)
      [[ $# -ge 2 ]] || { echo "error: --name requires an argument" >&2; exit 1; }
      branch=$(meb_slugify "$2")
      mode="branch"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage
      ;;
  esac
done

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
