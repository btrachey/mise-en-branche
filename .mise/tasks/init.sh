#!/usr/bin/env bash
#MISE description="Clone repo as bare and create main worktree"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/terminal.sh"

# ---------------------------------------------------------------------------
# Setup — prompt for any missing variables (required and optional)
# ---------------------------------------------------------------------------

gum style --bold "mise-en-branche setup"
echo ""

# Required: MEB_REPO
if [[ -z "${MEB_REPO:-}" ]]; then
  _meb_prompt_and_set MEB_REPO \
    gum input \
      --placeholder "owner/repo" \
      --prompt "GitHub repository: "
fi

# Required: MEB_TRACKER
if [[ -z "${MEB_TRACKER:-}" ]]; then
  _meb_prompt_and_set MEB_TRACKER \
    gum choose \
      --header "Issue tracker:" \
      "github" "linear" "none"
fi

# Required when linear: MEB_LINEAR_TEAM
if [[ "$MEB_TRACKER" == "linear" && -z "${MEB_LINEAR_TEAM:-}" ]]; then
  _meb_prompt_and_set MEB_LINEAR_TEAM \
    gum input \
      --placeholder "PROJ" \
      --prompt "Linear team key: "
fi

# Optional: MEB_TERMINAL (auto-detect current terminal to propose as default)
if [[ -z "${MEB_TERMINAL:-}" ]]; then
  detected=$(meb_detect_terminal)
  # Build option list with detected value first so gum pre-selects it
  terminal_opts=("$detected")
  for opt in "none" "cmux" "kitty" "iterm2" "alacritty" "ghostty"; do
    [[ "$opt" != "$detected" ]] && terminal_opts+=("$opt")
  done
  _meb_prompt_and_set_optional MEB_TERMINAL \
    gum choose \
      --header "Terminal integration (detected: $detected — Esc to skip):" \
      "${terminal_opts[@]}"
fi

# Optional: MEB_WORKTREE_PREFIX
if [[ -z "${MEB_WORKTREE_PREFIX:-}" ]]; then
  _meb_prompt_and_set_optional MEB_WORKTREE_PREFIX \
    gum input \
      --placeholder "(leave blank for repo root)" \
      --prompt "Worktree prefix path: "
fi

echo ""

# ---------------------------------------------------------------------------
# Validate that everything is in order before touching the filesystem
# ---------------------------------------------------------------------------

meb_config_validate

if [[ -d ".bare" ]]; then
  echo "error: .bare/ already exists — repository is already initialised" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Initialise
# ---------------------------------------------------------------------------

echo "Cloning $MEB_REPO as bare repository..."
gh repo clone "$MEB_REPO" .bare -- --bare

echo "Resolving default branch..."
default_branch=$(meb_default_branch)

# Write .git file so standard git tools can find the repo
echo "gitdir: .bare" > .git

# Ensure worktrees can be added (some git versions need this unset)
git -C .bare config --unset core.bare 2>/dev/null || true

# Fetch refs so worktree add can resolve the branch
git -C .bare fetch --all --quiet

echo "Creating worktree for '$default_branch'..."
worktree_dir="${MEB_WORKTREE_PREFIX:-}${default_branch}"
git -C .bare worktree add "../${worktree_dir}" "$default_branch"

echo ""
echo "Initialised successfully. Layout:"
echo "  .bare/          ← bare repository"
echo "  .git            ← gitdir pointer"
echo "  ${worktree_dir}/  ← worktree for '$default_branch'"
echo ""
echo "Run 'mise run add-worktree' to create additional worktrees."

meb_open_window "$(pwd)/${worktree_dir}" "$default_branch"
