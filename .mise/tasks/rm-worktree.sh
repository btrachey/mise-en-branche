#!/usr/bin/env bash
#MISE description="Remove a worktree interactively or by identifier"
#USAGE arg "[path]" help="Worktree directory path"
#USAGE flag "--branch <branch>" help="Identify worktree by branch name"
#USAGE flag "--gh <number>" help="Identify by GitHub issue (reverse slug lookup)"
#USAGE flag "--linear <id>" help="Identify by Linear issue (reverse slug lookup)"
#USAGE flag "--force" help="Skip confirmation and force removal"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/git.sh"
. "$SCRIPT_DIR/lib/tracker.sh"

meb_config_validate

force="${usage_force:-false}"
targets=()

if [[ -n "${usage_path:-}" ]]; then
  targets+=("$usage_path")
fi

if [[ -n "${usage_branch:-}" ]]; then
  path=$(meb_worktree_path_for_branch "$usage_branch")
  if [[ -z "$path" ]]; then
    echo "error: no worktree found for branch '$usage_branch'" >&2
    exit 1
  fi
  targets+=("$path")
fi

if [[ -n "${usage_gh:-}" ]]; then
  branch=$(MEB_TRACKER=github meb_issue_to_branch "$usage_gh")
  path=$(meb_worktree_path_for_branch "$branch")
  if [[ -z "$path" ]]; then
    echo "error: no worktree found for GitHub issue #$usage_gh (branch: $branch)" >&2
    exit 1
  fi
  targets+=("$path")
fi

if [[ -n "${usage_linear:-}" ]]; then
  branch=$(MEB_TRACKER=linear meb_issue_to_branch "$usage_linear")
  path=$(meb_worktree_path_for_branch "$branch")
  if [[ -z "$path" ]]; then
    echo "error: no worktree found for Linear issue $usage_linear (branch: $branch)" >&2
    exit 1
  fi
  targets+=("$path")
fi

# Interactive mode: multi-select from existing worktrees
if [[ ${#targets[@]} -eq 0 ]]; then
  worktree_list=$(meb_list_worktrees)
  if [[ -z "$worktree_list" ]]; then
    echo "No worktrees to remove."
    exit 0
  fi

  # Format for display: "BRANCH  PATH  [dirty]"
  display=$(echo "$worktree_list" | awk -F'\t' '{
    status = ($3 == "dirty") ? " [dirty]" : ""
    printf "%s  %s%s\n", $1, $2, status
  }')

  selected=$(echo "$display" | gum choose --no-limit --header "Select worktrees to remove:")
  if [[ -z "$selected" ]]; then
    echo "Aborted." >&2
    exit 0
  fi

  # Extract paths from selected display lines (field 2)
  while IFS= read -r line; do
    path=$(echo "$line" | awk '{ print $2 }')
    targets+=("$path")
  done <<< "$selected"
fi

# Remove each target
for path in "${targets[@]}"; do
  if [[ "$force" == false ]]; then
    if ! gum confirm "Remove worktree at $path?"; then
      echo "Skipped: $path"
      continue
    fi
  fi

  echo "Removing worktree: $path"
  git_args=(worktree remove)
  [[ "$force" == true ]] && git_args+=(--force)
  git_args+=("$path")

  if ! meb_git "${git_args[@]}" 2>/dev/null; then
    echo "warning: git worktree remove failed, attempting forced cleanup" >&2
    meb_git worktree remove --force "$path" 2>/dev/null || true
  fi

  # Clean up directory if it still exists
  if [[ -d "$path" ]]; then
    rm -rf "$path"
  fi

  echo "Removed: $path"
done
