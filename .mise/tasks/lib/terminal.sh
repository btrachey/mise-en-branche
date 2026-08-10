#!/usr/bin/env bash
set -euo pipefail

# meb_detect_terminal — guess the active terminal multiplexer/emulator
# Returns one of: tmux, cmux, kitty, iterm2, alacritty, ghostty, wezterm, none
meb_detect_terminal() {
  if [[ -n "${TMUX:-}" ]]; then
    echo "tmux"
  elif [[ -n "${CMUX_WORKSPACE_ID:-}" && -n "${CMUX_SURFACE_ID:-}" ]]; then
    echo "cmux"
  elif [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
    echo "kitty"
  elif [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    echo "iterm2"
  elif [[ "${TERM:-}" == "alacritty" ]]; then
    echo "alacritty"
  elif [[ "${TERM_PROGRAM:-}" == "ghostty" || -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
    echo "ghostty"
  elif [[ "${TERM_PROGRAM:-}" == "WezTerm" || -n "${WEZTERM_PANE:-}" ]]; then
    echo "wezterm"
  else
    echo "none"
  fi
}

# meb_open_window — open a terminal window/tab at the given path
# Usage: meb_open_window <path> <name>
meb_open_window() {
  local path="$1"
  local name="$2"

  case "${MEB_TERMINAL:-none}" in
    tmux)
      # Requires an active tmux session; creates a new window within it
      tmux new-window -c "$path" -n "$name"
      ;;

    cmux)
      cmux open "$path"
      ;;

    kitty)
      # Requires allow_remote_control in kitty.conf; opens a new tab in the current window
      kitten @ launch --type=tab --tab-title "$name" --cwd "$path"
      ;;

    iterm2)
      local escaped_path
      escaped_path=$(printf '%s' "$path" | sed "s/'/'\\''/g")
      osascript \
        -e 'tell application "iTerm2"' \
        -e '  tell current window' \
        -e "    create tab with default profile command \"cd '${escaped_path}' && exec \$SHELL\"" \
        -e '  end tell' \
        -e 'end tell'
      ;;

    alacritty)
      # Opens a new Alacritty window; no native tab support
      alacritty --title "$name" --working-directory "$path" &
      ;;

    ghostty)
      ghostty --working-directory="$path"
      ;;

    wezterm)
      # Requires a running wezterm mux server; opens a new tab and renames it
      local pane_id
      pane_id=$(wezterm cli spawn --cwd "$path")
      wezterm cli set-tab-title --pane-id "$pane_id" "$name"
      ;;

    none|"")
      echo "$path"
      ;;

    *)
      echo "error: unknown MEB_TERMINAL value: ${MEB_TERMINAL}" >&2
      exit 1
      ;;
  esac
}
