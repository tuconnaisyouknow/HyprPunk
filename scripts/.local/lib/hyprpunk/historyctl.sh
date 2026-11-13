#!/usr/bin/env bash
# What the shell remembers of what you do: the clipboard history (Super+V), whether it's
# kept and how much of it, and the launcher's and emoji picker's recent picks. Every copy
# comes through here (autostart.lua), so turning the history off stops it at once. The
# settings window and `hyprpunk history` change it.
#   historyctl.sh get                         every setting, as key=value
#   historyctl.sh set clipboard <true|false>  keep a clipboard history
#   historyctl.sh set size <items>            how many copies it keeps
#   historyctl.sh store                       what wl-paste --watch runs on each copy
#   historyctl.sh clear <clipboard|launcher|emoji>
#   historyctl.sh ensure                      fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk"
STATE_FILE="$STATE_DIR/history.conf"
# The clipboard panel's image thumbnails
THUMBNAILS="${XDG_CACHE_HOME:-$HOME/.cache}/hyprpunk/clipboard"

declare -A DEFAULTS=(
  [clipboard]=true
  [size]=750
)
KEYS=(clipboard size)

valid() {
  case "$1" in
  clipboard) [[ "$2" == "true" || "$2" == "false" ]] ;;
  size) [[ "$2" =~ ^[1-9][0-9]*$ ]] ;;
  esac
}

case "${1:-}" in
# The copy comes on stdin. cliphist itself skips what a password manager marks as
# sensitive (CLIPBOARD_STATE).
store)
  settings_load
  if [[ "${SETTINGS[clipboard]}" == "true" ]]; then
    exec cliphist -max-items "${SETTINGS[size]}" store
  fi
  cat >/dev/null
  ;;
# The panels watch their history files, so an empty one empties them on the spot
clear)
  case "${2:-}" in
  clipboard)
    cliphist wipe
    rm -rf "$THUMBNAILS"
    ;;
  launcher) printf '{}' >"$STATE_DIR/launcher-history.json" ;;
  emoji) printf '[]' >"$STATE_DIR/emoji-history.json" ;;
  *)
    echo "Usage: $(basename "$0") clear <clipboard|launcher|emoji>" >&2
    exit 1
    ;;
  esac
  ;;
*) settings_main "$@" ;;
esac
