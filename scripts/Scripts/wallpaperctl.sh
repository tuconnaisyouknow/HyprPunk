#!/usr/bin/env bash
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
STATE_FILE="${HYPR_WALLPAPER_STATE:-$STATE_DIR/wallpaper.conf}"
LOCK_FRAGMENT="$STATE_DIR/hyprlock-wallpaper.conf"
HYPRPAPER_FRAGMENT="$STATE_DIR/hyprpaper-wallpaper.conf"
LOCK_FILE="${STATE_FILE}.lock"
DEFAULT_WALLPAPER="$HOME/Pictures/Wallpapers/night-drive-protocol.png"

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
  local wallpaper="$1" dir tmp lock_tmp hyprpaper_tmp
  dir="$(dirname "$STATE_FILE")"
  mkdir -p "$dir" "$STATE_DIR"
  tmp="$(mktemp --tmpdir="$dir" wallpaper-state.XXXXXX)"
  lock_tmp="$(mktemp --tmpdir="$STATE_DIR" hyprlock-wallpaper.XXXXXX)"
  hyprpaper_tmp="$(mktemp --tmpdir="$STATE_DIR" hyprpaper-wallpaper.XXXXXX)"
  printf 'wallpaper=%s\n' "$wallpaper" >"$tmp"
  printf '%s\n' "\$wallpaper = $wallpaper" >"$lock_tmp"
  printf 'wallpaper {\n  monitor =\n  path = %s\n}\n' "$wallpaper" >"$hyprpaper_tmp"
  mv -f "$tmp" "$STATE_FILE"
  mv -f "$lock_tmp" "$LOCK_FRAGMENT"
  mv -f "$hyprpaper_tmp" "$HYPRPAPER_FRAGMENT"
}

ensure_state() {
  local wallpaper
  wallpaper="$(read_wallpaper || true)"
  if ! validate_wallpaper "$wallpaper" >/dev/null 2>&1; then
    validate_wallpaper "$DEFAULT_WALLPAPER"
    wallpaper="$DEFAULT_WALLPAPER"
  fi
  write_state "$wallpaper"
}

apply_wallpaper() {
  local wallpaper attempts=0
  wallpaper="$(read_wallpaper)"
  validate_wallpaper "$wallpaper"

  while ((attempts < 20)); do
    if hyprctl hyprpaper wallpaper ",$wallpaper" >/dev/null 2>&1; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 0.1
  done
  echo "Unable to apply wallpaper: Hyprpaper is not ready." >&2
  return 2
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
  apply_wallpaper
  ;;
set)
  [[ $# -eq 2 ]] || { usage >&2; exit 1; }
  acquire_lock
  wallpaper="$(realpath -m -s -- "$2")"
  validate_wallpaper "$wallpaper"
  write_state "$wallpaper"
  apply_wallpaper
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
    apply_wallpaper
  fi
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
