#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/git.sh"

meb_config_validate

usage() {
  cat >&2 <<EOF
Usage: mise run prune [OPTIONS]

Remove worktrees whose branches have been merged.

Options:
  --dry-run   Print candidates without removing anything
  --yes       Skip confirmation prompt

EOF
  exit 1
}

dry_run=false
yes=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=true
      shift
      ;;
    --yes)
      yes=true
      shift
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

default_branch=$(meb_default_branch)

# Collect merged worktrees (exclude default branch)
merged=()
while IFS=$'\t' read -r branch path _dirty; do
  [[ "$branch" == "$default_branch" ]] && continue
  if meb_branch_is_merged "$branch"; then
    merged+=("$branch:$path")
  fi
done < <(meb_list_worktrees)

if [[ ${#merged[@]} -eq 0 ]]; then
  echo "No merged worktrees to prune."
  exit 0
fi

echo "Merged worktrees eligible for removal:"
echo ""
for entry in "${merged[@]}"; do
  branch="${entry%%:*}"
  path="${entry#*:}"
  printf "  %-40s %s\n" "$branch" "$path"
done
echo ""

if [[ "$dry_run" == true ]]; then
  echo "(dry-run) No changes made."
  exit 0
fi

if [[ "$yes" == false ]]; then
  if ! gum confirm "Remove ${#merged[@]} merged worktree(s)?"; then
    echo "Aborted."
    exit 0
  fi
fi

for entry in "${merged[@]}"; do
  branch="${entry%%:*}"
  path="${entry#*:}"
  echo "Removing worktree for '$branch' at $path..."

  if ! meb_git worktree remove "$path" 2>/dev/null; then
    meb_git worktree remove --force "$path" 2>/dev/null || true
  fi

  if [[ -d "$path" ]]; then
    rm -rf "$path"
  fi

  echo "  Removed: $path"
done

# Clean up stale worktree metadata
meb_git worktree prune

echo ""
echo "Done. Pruned ${#merged[@]} worktree(s)."
