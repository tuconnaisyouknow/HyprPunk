#!/usr/bin/env bash
# Remembers the wallpaper and hands it to awww, which forgets it on every restart.
#   wallpaperctl.sh apply        puts the saved one back, at once (login, new screen)
#   wallpaperctl.sh set <image>  saves it and shows it with a transition (the shell's selector)
#   wallpaperctl.sh reset        back to the default one
#   wallpaperctl.sh ensure       makes sure a valid wallpaper is saved
#   wallpaperctl.sh init         saves the default one without showing it (install.sh)
#   wallpaperctl.sh status       prints the saved one
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
STATE_FILE="${HYPR_WALLPAPER_STATE:-$STATE_DIR/wallpaper.conf}"
LOCK_FILE="${STATE_FILE}.lock"
DEFAULT_WALLPAPER="$HOME/Pictures/Wallpapers/night-drive-protocol.png"
# The new wallpaper grows as a circle out of the island, where the selector opens
TRANSITION=(--transition-type grow --transition-pos top --transition-duration 1.2 --transition-fps 60)

usage() {
  cat <<EOF
Usage:
  $(basename "$0") ensure
  $(basename "$0") apply
  $(basename "$0") set <image>
  $(basename "$0") status
  $(basename "$0") reset
  $(basename "$0") init
EOF
}

# One change at a time, even when the selector and a new screen ask together
acquire_lock() {
  if [[ "${WALLPAPERCTL_LOCKED:-false}" == "true" ]]; then
    return 0
  fi
  command -v flock >/dev/null 2>&1 || {
    echo "flock is required to update the wallpaper state." >&2
    exit 3
  }
  mkdir -p "$STATE_DIR"
  exec 9>"$LOCK_FILE"
  flock -w 10 -x 9 || {
    echo "Timed out waiting for the wallpaper state lock." >&2
    exit 3
  }
  export WALLPAPERCTL_LOCKED=true
}

read_wallpaper() {
  [[ -f "$STATE_FILE" ]] || return 0
  awk -F= '$1 == "wallpaper" { print substr($0, length($1) + 2); exit }' "$STATE_FILE"
}

validate_wallpaper() {
  local path="$1"
  [[ "$path" != *$'\n'* && -f "$path" ]] || {
    echo "Wallpaper not found: $path" >&2
    return 1
  }
  case "${path,,}" in
  *.jpg | *.jpeg | *.png | *.webp) ;;
  *)
    echo "Unsupported wallpaper format: $path" >&2
    return 1
    ;;
  esac
}

write_state() {
  local wallpaper="$1" dir tmp
  dir="$(dirname "$STATE_FILE")"
  mkdir -p "$dir" "$STATE_DIR"
  tmp="$(mktemp --tmpdir="$dir" wallpaper-state.XXXXXX)"
  printf 'wallpaper=%s\n' "$wallpaper" >"$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

# A missing or broken saved wallpaper falls back to the default one
ensure_state() {
  local wallpaper
  wallpaper="$(read_wallpaper || true)"
  if ! validate_wallpaper "$wallpaper" >/dev/null 2>&1; then
    validate_wallpaper "$DEFAULT_WALLPAPER"
    wallpaper="$DEFAULT_WALLPAPER"
  fi
  write_state "$wallpaper"
}

# Shows the saved wallpaper, the arguments go to awww img (the transition)
apply_wallpaper() {
  local wallpaper attempts=0
  wallpaper="$(read_wallpaper)"
  validate_wallpaper "$wallpaper"

  # awww-daemon starts alongside us at login, give it up to 5 seconds
  until awww query >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if ((attempts >= 50)); then
      echo "Unable to apply wallpaper: awww-daemon is not ready." >&2
      return 2
    fi
    sleep 0.1
  done
  awww img "$@" -- "$wallpaper"
}

command="${1:-}"
case "$command" in
ensure)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  ensure_state
  ;;
apply)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  ensure_state
  apply_wallpaper --transition-type none
  ;;
set)
  [[ $# -eq 2 ]] || { usage >&2; exit 1; }
  acquire_lock
  wallpaper="$(realpath -m -s -- "$2")"
  validate_wallpaper "$wallpaper"
  write_state "$wallpaper"
  apply_wallpaper "${TRANSITION[@]}"
  ;;
status)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  wallpaper="$(read_wallpaper || true)"
  printf 'wallpaper=%s\n' "${wallpaper:-$DEFAULT_WALLPAPER}"
  ;;
reset | init)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  validate_wallpaper "$DEFAULT_WALLPAPER"
  write_state "$DEFAULT_WALLPAPER"
  if [[ "$command" == "reset" ]]; then
    apply_wallpaper "${TRANSITION[@]}"
  fi
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
