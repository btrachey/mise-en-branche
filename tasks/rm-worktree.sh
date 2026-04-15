#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/git.sh"
. "$SCRIPT_DIR/lib/tracker.sh"

meb_config_validate

usage() {
  cat >&2 <<EOF
Usage: mise run rm-worktree [OPTIONS] [PATH]

Options:
  (none)          Interactive multi-select picker
  <path>          Remove worktree at the given path
  --branch <n>    Identify worktree by branch name
  --gh <number>   Identify by GitHub issue (reverse slug lookup)
  --linear <id>   Identify by Linear issue (reverse slug lookup)
  --force         Skip confirmation and force removal

EOF
  exit 1
}

force=false
targets=()  # list of worktree paths to remove

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      [[ $# -ge 2 ]] || { echo "error: --branch requires an argument" >&2; exit 1; }
      path=$(meb_worktree_path_for_branch "$2")
      if [[ -z "$path" ]]; then
        echo "error: no worktree found for branch '$2'" >&2
        exit 1
      fi
      targets+=("$path")
      shift 2
      ;;
    --gh)
      [[ $# -ge 2 ]] || { echo "error: --gh requires an argument" >&2; exit 1; }
      branch=$(MEB_TRACKER=github meb_issue_to_branch "$2")
      path=$(meb_worktree_path_for_branch "$branch")
      if [[ -z "$path" ]]; then
        echo "error: no worktree found for GitHub issue #$2 (branch: $branch)" >&2
        exit 1
      fi
      targets+=("$path")
      shift 2
      ;;
    --linear)
      [[ $# -ge 2 ]] || { echo "error: --linear requires an argument" >&2; exit 1; }
      branch=$(MEB_TRACKER=linear meb_issue_to_branch "$2")
      path=$(meb_worktree_path_for_branch "$branch")
      if [[ -z "$path" ]]; then
        echo "error: no worktree found for Linear issue $2 (branch: $branch)" >&2
        exit 1
      fi
      targets+=("$path")
      shift 2
      ;;
    --force)
      force=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage
      ;;
    *)
      # Treat as a path
      targets+=("$1")
      shift
      ;;
  esac
done

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
