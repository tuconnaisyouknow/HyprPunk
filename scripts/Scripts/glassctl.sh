#!/usr/bin/env bash
# Picks the shell's glass: classic, with its crisp rim, or liquid, the lock screen
# clock's see-through glass with a soft rim. The shell watches the saved choice and
# restyles itself on the spot, and Hyprland is reloaded so its blur reaches the
# fainter liquid glass (see glass_state.lua).
#   glassctl.sh get
#   glassctl.sh set <classic|liquid> | toggle   from the control center

set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
STATE_FILE="$STATE_DIR/glass-style"

usage() {
  echo "Usage: $0 {get|set <classic|liquid>|toggle}"
}

# The saved style, classic when there's none yet
read_style() {
  local style="classic"
  if [[ -r "$STATE_FILE" ]]; then
    IFS= read -r style <"$STATE_FILE" || true
  fi
  [[ "$style" == "liquid" ]] && printf 'liquid\n' || printf 'classic\n'
}

write_style() {
  local temporary
  mkdir -p "$STATE_DIR"
  temporary=$(mktemp --tmpdir="$STATE_DIR" glass-style.XXXXXX)
  printf '%s\n' "$1" >"$temporary"
  mv -f "$temporary" "$STATE_FILE"
  hyprctl reload >/dev/null 2>&1 || true
}

case "${1:-}" in
get)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  read_style
  ;;
set)
  [[ $# -eq 2 && ("$2" == "classic" || "$2" == "liquid") ]] || { usage >&2; exit 1; }
  write_style "$2"
  ;;
toggle)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  [[ "$(read_style)" == "liquid" ]] && write_style classic || write_style liquid
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
