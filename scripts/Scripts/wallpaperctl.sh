#!/usr/bin/env bash
# Remembers the wallpaper and hands it to awww, which forgets it on every restart.
# Wallpapers live in ~/Pictures/Wallpapers/<theme>/<subtheme>/, and the one you pick
# decides the whole look: the theme, the colors, the folders and the login screen. Each
# theme remembers its last wallpaper.
#   wallpaperctl.sh apply          puts the saved one back, at once (login, new screen)
#   wallpaperctl.sh set <image>    saves it and shows it with a transition (the shell's selector)
#   wallpaperctl.sh theme <theme>  switches to the theme's last wallpaper, or its first one
#   wallpaperctl.sh themes         prints each theme, the wallpaper it would switch to and its thumbnail (the theme picker)
#   wallpaperctl.sh list [theme]   prints the theme's wallpapers in order and their thumbnails (the current theme's by default)
#   wallpaperctl.sh reset          back to the current theme's first wallpaper
#   wallpaperctl.sh login          puts the saved one's login screen and colors back (sddm.sh, after an update)
#   wallpaperctl.sh init           gives the default one's look without showing it, and makes every thumbnail (install.sh)
#   wallpaperctl.sh status         prints the saved one and its theme
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
STATE_FILE="$STATE_DIR/wallpaper.conf"
LOCK_FILE="${STATE_FILE}.lock"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_THEME="neon"
MATUGEN_DIR="$HOME/.config/matugen"
PALETTES="$MATUGEN_DIR/palettes.conf"
THUMBNAIL_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprpunk/thumbnails"
LOGIN_SCREEN="/usr/local/bin/hyprpunk-login-screen"
LOGIN_COLORS="$STATE_DIR/login-colors.conf"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ICON_THEMES="$DATA_HOME/icons"
PAPIRUS="/usr/share/icons/Papirus-Dark"
# The sizes Papirus colors its folders in
FOLDER_SIZES=(22 24 32 48 64)
# The new wallpaper grows as a circle out of the island, where the selector opens
TRANSITION=(--transition-type grow --transition-pos top --transition-duration 1.2 --transition-fps 60)

usage() {
  cat <<EOF
Usage:
  $(basename "$0") apply
  $(basename "$0") set <image>
  $(basename "$0") theme <theme>
  $(basename "$0") themes
  $(basename "$0") list [theme]
  $(basename "$0") reset
  $(basename "$0") login
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

# The value of a key=value line, empty when the file or the key is missing
conf_value() {
  [[ -f "$1" ]] || return 0
  awk -F= -v key="$2" '$1 == key { print substr($0, length($1) + 2); exit }' "$1"
}

# The state holds the wallpaper, and each theme's last one under the theme's name
read_key() {
  conf_value "$STATE_FILE" "$1"
}

# The theme is the wallpaper's first folder under ~/Pictures/Wallpapers
theme_of() {
  local relative="${1#"$WALLPAPER_DIR"/}"
  printf '%s\n' "${relative%%/*}"
}

# Its subtheme is the folder below, and names its login screen
subtheme_of() {
  local relative="${1#"$WALLPAPER_DIR"/*/}"
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

# Every theme with a wallpaper, as theme<tab>wallpaper: the default one first, the others
# in their folders' order
list_themes() {
  local theme wallpaper
  {
    printf '%s\n' "$DEFAULT_THEME"
    find -L "$WALLPAPER_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' ! -name "$DEFAULT_THEME" -printf '%f\n' |
      LC_ALL=C sort
  } | while IFS= read -r theme; do
    wallpaper="$(theme_wallpaper "$theme" 2>/dev/null)" || continue
    printf '%s\t%s\n' "$theme" "$wallpaper"
  done
}

# The pickers show thumbnails: Qt decodes the whole picture to shrink it, which takes up
# to a second for a 4K wallpaper and a few milliseconds for a thumbnail. Each one is made
# once, and again only when its wallpaper changes.
thumbnail_of() {
  printf '%s/%s.jpg\n' "$THUMBNAIL_DIR" "${1#"$WALLPAPER_DIR"/}"
}

make_thumbnail() {
  local thumbnail
  thumbnail="$(thumbnail_of "$1")"
  [[ "$thumbnail" -nt "$1" ]] && return 0
  mkdir -p "${thumbnail%/*}"
  if magick "$1[0]" -thumbnail 640x360 -quality 85 "$thumbnail.tmp.jpg"; then
    mv -f "$thumbnail.tmp.jpg" "$thumbnail"
  else
    rm -f "$thumbnail.tmp.jpg"
    echo "Unable to make a thumbnail of $1" >&2
  fi
}

# Adds the thumbnail to lines ending with a wallpaper, making the missing ones side by side
with_thumbnails() {
  local lines=() line running=0 cores
  cores="$(nproc)"
  mapfile -t lines
  for line in "${lines[@]}"; do
    make_thumbnail "${line##*$'\t'}" &
    running=$((running + 1))
    if ((running >= cores)); then
      wait -n || true
      running=$((running - 1))
    fi
  done
  wait
  for line in "${lines[@]}"; do
    printf '%s\t%s\n' "$line" "$(thumbnail_of "${line##*$'\t'}")"
  done
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

# Every wallpaper has its own palette, picked by hand and named in palettes.conf
palette_of() {
  local name
  name="$(conf_value "$PALETTES" "${1#"$WALLPAPER_DIR"/}")"
  [[ -n "$name" && -f "$MATUGEN_DIR/palettes/$name.json" ]] || {
    echo "No palette for this wallpaper: $1" >&2
    return 1
  }
  printf '%s\n' "$MATUGEN_DIR/palettes/$name.json"
}

# matugen writes every app's colors from it, kept between sessions
render_colors() {
  local palette
  palette="$(palette_of "$1")"
  matugen -q json "$palette"
}

# pkexec, since the login screen is the system's, and polkit lets this tool through. It
# gets the colors matugen wrote for it on its input.
set_login_screen() {
  pkexec "$LOGIN_SCREEN" "$(subtheme_of "$1")" <"$LOGIN_COLORS"
}

# Papirus's folder color nearest to the palette's accent, by the front of each folder,
# the last of its three fills. In OKLab, so the nearest is the one that looks nearest.
folder_color_of() {
  local accent color face
  accent="$(jq -r .colors.primary.default.color "$(palette_of "$1")")"
  papirus-folders -l --theme Papirus-Dark | tr -d ' >' | while IFS= read -r color; do
    face="$(grep -o 'fill:#[0-9a-fA-F]\{6\}' "$PAPIRUS/48x48/places/folder-$color.svg" | sed -n 3p)"
    if [[ -n "$face" ]]; then
      printf '%s %s\n' "$color" "${face#fill:}"
    fi
  done | awk -v accent="$accent" '
    function digit(h, i) { return index("0123456789abcdef", substr(tolower(h), i, 1)) - 1 }
    function linear(i, h, c) { c = (digit(h, i) * 16 + digit(h, i + 1)) / 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
    function cbrt(x) { return x ^ (1 / 3) }
    function oklab(h, lab, r, g, b, l, m, s) {
      r = linear(2, h); g = linear(4, h); b = linear(6, h)
      l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
      m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
      s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
      lab[1] = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
      lab[2] = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
      lab[3] = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    }
    BEGIN { oklab(accent, target); best = -1 }
    {
      oklab($2, lab)
      d = (lab[1] - target[1]) ^ 2 + (lab[2] - target[2]) ^ 2 + (lab[3] - target[3]) ^ 2
      if (best < 0 || d < best) { best = d; nearest = $1 }
    }
    END { print nearest }'
}

# The HyprPunk icon theme, which every app uses: Papirus-Dark with its folders in one
# color, without touching Papirus. Each color is a small hidden theme of its own,
# HyprPunk-<color>, made the first time it's needed: links from the folders' usual names
# to that color's icons. HyprPunk is a link to one of them, so a new color is a new
# link, at once.
make_folder_theme() {
  local color="$1" theme size icon name target aliases added dirs="" scaled="" sections=""
  theme="$(mktemp -d --tmpdir="$ICON_THEMES" ".HyprPunk-$color.XXXXXX")"
  chmod 755 "$theme"
  for size in "${FOLDER_SIZES[@]}"; do
    mkdir "$theme/${size}x$size"
    for icon in "$PAPIRUS/${size}x$size/places/"{folder,user}-"$color"{-*,}.svg; do
      [[ -e "$icon" ]] || continue
      name="${icon##*/}"
      ln -s "$icon" "$theme/${size}x$size/${name/-"$color"/}"
    done
    # Papirus's other names for them (folder-publicshare for folder-image-people…) point
    # inside Papirus, so they come along too, pointing here. Again until none is left, for
    # the names of names.
    aliases="$(find "$PAPIRUS/${size}x$size/places" -maxdepth 1 -type l -name '*.svg' -printf '%f\t%l\n')"
    added=true
    while $added; do
      added=false
      while IFS=$'\t' read -r name target; do
        [[ ! -e "$theme/${size}x$size/$name" && "$target" != */* && -e "$theme/${size}x$size/$target" ]] || continue
        ln -s "$target" "$theme/${size}x$size/$name"
        added=true
      done <<<"$aliases"
    done
    # Twice as sharp, from the same drawings, like Papirus
    ln -s "${size}x$size" "$theme/${size}x$size@2x"
    dirs+="${size}x$size,"
    scaled+="${size}x$size@2x,"
    sections+="$(printf '\n[%sx%s]\nContext=Places\nSize=%s\nType=Fixed\n' "$size" "$size" "$size")"
    sections+="$(printf '\n\n[%sx%s@2x]\nContext=Places\nSize=%s\nScale=2\nType=Fixed\n' "$size" "$size" "$size")"
  done
  printf '[Icon Theme]\nName=HyprPunk\nComment=Papirus-Dark, with its folders in the wallpaper'"'"'s accent\nInherits=Papirus-Dark\nHidden=true\nDirectories=%s\nScaledDirectories=%s\n%s\n' \
    "${dirs%,}" "${scaled%,}" "$sections" >"$theme/index.theme"
  mv -T "$theme" "$ICON_THEMES/HyprPunk-$color"
}

set_folder_color() {
  local color
  color="$(folder_color_of "$1")"
  mkdir -p "$ICON_THEMES"
  [[ -d "$ICON_THEMES/HyprPunk-$color" ]] || make_folder_theme "$color"
  # Open GTK windows take the new folders when they next redraw
  ln -sfnT "HyprPunk-$color" "$ICON_THEMES/HyprPunk"
}

# A new wallpaper and its look. The colors come first: a wallpaper without a palette
# stops here, before anything changes. The login screen comes last, since you only
# see it at the next login. Without awww arguments the wallpaper isn't shown (install.sh).
switch_to() {
  local wallpaper="$1"
  shift
  render_colors "$wallpaper"
  write_state "$wallpaper"
  if (($#)); then
    show_wallpaper "$wallpaper" "$@"
  fi
  set_folder_color "$wallpaper"
  set_login_screen "$wallpaper"
}

command="${1:-}"
case "$command:$#" in
apply:1)
  acquire_lock
  wallpaper="$(saved_wallpaper)"
  # Its look is already in place, unless the saved one is gone and the default replaces it
  if [[ "$wallpaper" == "$(read_key wallpaper)" ]]; then
    show_wallpaper "$wallpaper" --transition-type none
  else
    switch_to "$wallpaper" --transition-type none
  fi
  ;;
set:2)
  acquire_lock
  wallpaper="$(realpath -m -s -- "$2")"
  validate_wallpaper "$wallpaper"
  switch_to "$wallpaper" "${TRANSITION[@]}"
  ;;
theme:2)
  acquire_lock
  validate_theme "$2"
  switch_to "$(theme_wallpaper "$2")" "${TRANSITION[@]}"
  ;;
themes:1)
  list_themes | with_thumbnails
  ;;
list:1)
  list_wallpapers "$(theme_of "$(saved_wallpaper)")" | with_thumbnails
  ;;
list:2)
  list_wallpapers "$2" | with_thumbnails
  ;;
reset:1)
  acquire_lock
  switch_to "$(first_wallpaper "$(theme_of "$(saved_wallpaper)")")" "${TRANSITION[@]}"
  ;;
login:1)
  acquire_lock
  set_login_screen "$(saved_wallpaper)"
  ;;
init:1)
  acquire_lock
  switch_to "$(first_wallpaper "$DEFAULT_THEME")"
  # Every thumbnail, so the pickers open at once the first time too
  list_themes | cut -f1 | while IFS= read -r theme; do list_wallpapers "$theme"; done | with_thumbnails >/dev/null
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
