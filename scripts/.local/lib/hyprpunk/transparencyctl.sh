#!/usr/bin/env bash
# Picks which windows are see-through, with the wallpaper blurred behind them: all of
# them, the terminal alone or none. Hyprland reads the saved choice
# (transparency_state.lua) and is reloaded to follow it; the shell watches it for its
# settings window, which comes here like `hyprpunk transparency`.
#   transparencyctl.sh get
#   transparencyctl.sh set <all|terminal|none>

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk"
STATE_FILE="$STATE_DIR/transparency"

usage() {
  echo "Usage: $0 {get|set <all|terminal|none>}"
}

# The saved choice, the terminal alone when there's none yet
read_choice() {
  local choice="terminal"
  if [[ -r "$STATE_FILE" ]]; then
    IFS= read -r choice <"$STATE_FILE" || true
  fi
  [[ "$choice" == "all" || "$choice" == "none" ]] && printf '%s\n' "$choice" || printf 'terminal\n'
}

# Written whole and swapped in, so nothing ever reads half a file
write_choice() {
  local temporary
  mkdir -p "$STATE_DIR"
  temporary=$(mktemp --tmpdir="$STATE_DIR" transparency.XXXXXX)
  printf '%s\n' "$1" >"$temporary"
  mv -f "$temporary" "$STATE_FILE"
  hyprctl reload >/dev/null 2>&1 || true
}

case "${1:-}" in
get)
  [[ $# -eq 1 ]] || {
    usage >&2
    exit 1
  }
  read_choice
  ;;
set)
  [[ $# -eq 2 && ("$2" == "all" || "$2" == "terminal" || "$2" == "none") ]] || {
    usage >&2
    exit 1
  }
  write_choice "$2"
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
