#!/usr/bin/env bash
set -euo pipefail

# meb_git — run git against .bare
meb_git() {
  git -C .bare "$@"
}

# meb_slugify — convert a string to a branch-safe slug
# idempotent: same input always produces same output
meb_slugify() {
  local str="$1"
  echo "$str" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/ /-/g' \
    | sed 's/[^a-z0-9-]//g' \
    | sed 's/--*/-/g' \
    | sed 's/^-//; s/-$//' \
    | cut -c1-50
}

# meb_list_worktrees — list worktrees as BRANCH<TAB>PATH<TAB>DIRTY lines
# excludes the bare repo itself
meb_list_worktrees() {
  local output
  output=$(meb_git worktree list --porcelain)

  local path branch dirty
  path=""
  branch=""
  dirty="clean"

  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      # Emit previous entry if valid (skip bare)
      if [[ -n "$path" && -n "$branch" && "$branch" != "(bare)" ]]; then
        printf '%s\t%s\t%s\n' "$branch" "$path" "$dirty"
      fi
      path="${line#worktree }"
      branch=""
      dirty="clean"
    elif [[ "$line" == branch\ * ]]; then
      branch="${line#branch refs/heads/}"
    elif [[ "$line" == "bare" ]]; then
      branch="(bare)"
    elif [[ "$line" == "prunable"* || "$line" == "locked"* ]]; then
      : # ignore
    elif [[ "$line" == "" ]]; then
      : # blank separator between entries
    fi
    # Check for dirty marker (modified/untracked not shown in porcelain list,
    # we use git status instead)
  done <<< "$output"

  # Emit last entry
  if [[ -n "$path" && -n "$branch" && "$branch" != "(bare)" ]]; then
    # Check dirty status
    if ! git -C "$path" diff --quiet 2>/dev/null || ! git -C "$path" diff --cached --quiet 2>/dev/null; then
      dirty="dirty"
    fi
    printf '%s\t%s\t%s\n' "$branch" "$path" "$dirty"
  fi
}

# meb_worktree_path_for_branch — return path for a branch, or empty string
meb_worktree_path_for_branch() {
  local branch="$1"
  meb_list_worktrees | awk -F'\t' -v b="$branch" '$1 == b { print $2; exit }'
}

# meb_worktree_exists — return 0 if worktree exists for branch, 1 otherwise
meb_worktree_exists() {
  local branch="$1"
  local path
  path=$(meb_worktree_path_for_branch "$branch")
  [[ -n "$path" ]]
}

# meb_branch_is_merged — return 0 if branch is merged into HEAD, 1 otherwise
meb_branch_is_merged() {
  local branch="$1"
  meb_git branch --merged HEAD | grep -qE "^[[:space:]]+${branch}$"
}
