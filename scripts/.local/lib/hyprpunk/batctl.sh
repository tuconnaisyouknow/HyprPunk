#!/usr/bin/env bash
# bat's code colors, a theme per palette. bat only reads themes from its cache, and
# building it takes a moment: so every palette's theme is built once, and a new wallpaper
# only names its own in bat's config (matugen's config.toml). wallpaperctl.sh runs ensure
# with every palette.
#   batctl.sh ensure   builds the themes and the cache again, if a palette or the theme changed

set -euo pipefail

MATUGEN_DIR="$HOME/.config/matugen"
TEMPLATE="$MATUGEN_DIR/templates/bat.tmTheme.template"
MEANINGS="$MATUGEN_DIR/meanings.json"
THEMES="$HOME/.config/bat/themes"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/bat/themes.bin"
LOCK_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/bat.lock"

# Every palette has its theme, none is left from a palette that's gone, and the cache
# was built after the last change to any of them
up_to_date() {
  local palette theme
  local -a themes=("$THEMES"/HyprPunk-*.tmTheme) palettes=("$MATUGEN_DIR"/palettes/*.json)

  [[ -e "$CACHE" && "$CACHE" -nt "$TEMPLATE" && "$CACHE" -nt "$MEANINGS" ]] || return 1
  [[ "${#themes[@]}" -eq "${#palettes[@]}" ]] || return 1
  for palette in "${palettes[@]}"; do
    theme="$THEMES/HyprPunk-$(basename "$palette" .json).tmTheme"
    [[ -e "$theme" && "$CACHE" -nt "$palette" ]] || return 1
  done
}

# matugen renders one palette at a time, into the file its config names: a config per
# palette, with the theme alone
build() {
  local tmp palette name

  tmp=$(mktemp -d)
  mkdir "$tmp/themes"
  for palette in "$MATUGEN_DIR"/palettes/*.json; do
    name=$(basename "$palette" .json)
    cat >"$tmp/config.toml" <<CONFIG
[config]

[templates.bat]
input_path = "$TEMPLATE"
output_path = "$tmp/themes/HyprPunk-$name.tmTheme"
CONFIG
    matugen -q -c "$tmp/config.toml" --import-json "$MEANINGS" json "$palette"
  done

  mkdir -p "$THEMES"
  find "$THEMES" -maxdepth 1 -name '*.tmTheme' -delete
  mv -- "$tmp"/themes/*.tmTheme "$THEMES/"
  rm -rf -- "$tmp"
  bat cache --build >/dev/null
}

ensure() {
  # Two quick wallpaper changes check one after the other, and the second finds it built
  mkdir -p "$(dirname "$LOCK_FILE")"
  exec 9>"$LOCK_FILE"
  flock 9
  up_to_date || build
}

case "${1:-}" in
ensure) ensure ;;
*)
  echo "Usage: batctl.sh ensure" >&2
  exit 2
  ;;
esac
