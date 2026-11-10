#!/usr/bin/env bash
# Remembers the wallpaper and hands it to awww, which forgets it on every restart.
# Wallpapers live in ~/Pictures/Wallpapers/<theme>/<subtheme>/, and the one you pick
# decides the theme. Each theme remembers its last wallpaper.
#   wallpaperctl.sh apply          puts the saved one back, at once (login, new screen)
#   wallpaperctl.sh set <image>    saves it and shows it with a transition (the shell's selector)
#   wallpaperctl.sh theme <theme>  switches to the theme's last wallpaper, or its first one
#   wallpaperctl.sh list [theme]   prints the theme's wallpapers in order (the current theme's by default)
#   wallpaperctl.sh reset          back to the current theme's first wallpaper
#   wallpaperctl.sh init           saves the default one without showing it (install.sh)
#   wallpaperctl.sh status         prints the saved one and its theme
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
STATE_FILE="$STATE_DIR/wallpaper.conf"
LOCK_FILE="${STATE_FILE}.lock"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_THEME="neon"
# The new wallpaper grows as a circle out of the island, where the selector opens
TRANSITION=(--transition-type grow --transition-pos top --transition-duration 1.2 --transition-fps 60)

usage() {
  cat <<EOF
Usage:
  $(basename "$0") apply
  $(basename "$0") set <image>
  $(basename "$0") theme <theme>
  $(basename "$0") list [theme]
  $(basename "$0") reset
  $(basename "$0") init
  $(basename "$0") status
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

# The state holds the wallpaper, and each theme's last one under the theme's name
read_key() {
  [[ -f "$STATE_FILE" ]] || return 0
  awk -F= -v key="$1" '$1 == key { print substr($0, length($1) + 2); exit }' "$STATE_FILE"
}

# The theme is the wallpaper's first folder under ~/Pictures/Wallpapers
theme_of() {
  local relative="${1#"$WALLPAPER_DIR"/}"
  printf '%s\n' "${relative%%/*}"
}

validate_theme() {
  [[ "$1" != */* && "$1" != .* && -d "$WALLPAPER_DIR/$1" ]] || {
    echo "Theme not found: $1" >&2
    return 1
  }
}

# A wallpaper only counts inside <theme>/<subtheme>/, where its theme can be read
validate_wallpaper() {
  local path="$1" relative
  [[ "$path" != *$'\n'* && -f "$path" ]] || {
    echo "Wallpaper not found: $path" >&2
    return 1
  }
  relative="${path#"$WALLPAPER_DIR"/}"
  [[ "$relative" != "$path" && "$relative" == */*/* && "$relative" != */*/*/* ]] || {
    echo "Wallpaper outside $WALLPAPER_DIR/<theme>/<subtheme>/: $path" >&2
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

# Subthemes in their folders' order, then the wallpapers by name
list_wallpapers() {
  validate_theme "$1"
  find -L "$WALLPAPER_DIR/$1" -mindepth 2 -maxdepth 2 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) |
    LC_ALL=C sort
}

first_wallpaper() {
  local first
  first="$(list_wallpapers "$1" | head -n 1)"
  [[ -n "$first" ]] || {
    echo "No wallpaper in theme: $1" >&2
    return 1
  }
  printf '%s\n' "$first"
}

# The theme's last wallpaper while it still exists, its first one otherwise
theme_wallpaper() {
  local last
  last="$(read_key "$1")"
  if [[ -n "$last" ]] && validate_wallpaper "$last" 2>/dev/null && [[ "$(theme_of "$last")" == "$1" ]]; then
    printf '%s\n' "$last"
  else
    first_wallpaper "$1"
  fi
}

# Saves the wallpaper and remembers it as its theme's last one, keeping the others'
write_state() {
  local wallpaper="$1" theme tmp
  theme="$(theme_of "$wallpaper")"
  mkdir -p "$STATE_DIR"
  tmp="$(mktemp --tmpdir="$STATE_DIR" wallpaper-state.XXXXXX)"
  {
    printf 'wallpaper=%s\n' "$wallpaper"
    printf '%s=%s\n' "$theme" "$wallpaper"
    if [[ -f "$STATE_FILE" ]]; then
      awk -F= -v theme="$theme" '$1 != "wallpaper" && $1 != theme' "$STATE_FILE"
    fi
  } >"$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

# The saved wallpaper, or the default theme's when it's missing or moved
saved_wallpaper() {
  local wallpaper
  wallpaper="$(read_key wallpaper)"
  if validate_wallpaper "$wallpaper" 2>/dev/null; then
    printf '%s\n' "$wallpaper"
  else
    theme_wallpaper "$DEFAULT_THEME"
  fi
}

# Shows the wallpaper, the other arguments go to awww img (the transition)
show_wallpaper() {
  local wallpaper="$1" attempts=0
  shift

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

# Saves the wallpaper, then shows it with a transition
switch_to() {
  write_state "$1"
  show_wallpaper "$1" "${TRANSITION[@]}"
}

command="${1:-}"
case "$command:$#" in
apply:1)
  acquire_lock
  wallpaper="$(saved_wallpaper)"
  write_state "$wallpaper"
  show_wallpaper "$wallpaper" --transition-type none
  ;;
set:2)
  acquire_lock
  wallpaper="$(realpath -m -s -- "$2")"
  validate_wallpaper "$wallpaper"
  switch_to "$wallpaper"
  ;;
theme:2)
  acquire_lock
  validate_theme "$2"
  switch_to "$(theme_wallpaper "$2")"
  ;;
list:1)
  list_wallpapers "$(theme_of "$(saved_wallpaper)")"
  ;;
list:2)
  list_wallpapers "$2"
  ;;
reset:1)
  acquire_lock
  switch_to "$(first_wallpaper "$(theme_of "$(saved_wallpaper)")")"
  ;;
init:1)
  acquire_lock
  write_state "$(first_wallpaper "$DEFAULT_THEME")"
  ;;
status:1)
  wallpaper="$(saved_wallpaper)"
  printf 'wallpaper=%s\ntheme=%s\n' "$wallpaper" "$(theme_of "$wallpaper")"
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
