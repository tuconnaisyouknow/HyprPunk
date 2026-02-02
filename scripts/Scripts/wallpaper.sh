#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/Pictures/Wallpapers"
CONFIG_PATH="$HOME/.config/hypr/hyprpaper.conf"
LOCK_CONFIG="$HOME/.config/hypr/hyprlock.conf"
THEME_PATH="$HOME/.config/rofi/catppuccin-wallpaper.rasi"

generate_rofi_list() {
  find -L "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) -print0 |
    while IFS= read -r -d '' img; do
      name="$(basename "$img")"
      printf '%s\0icon\x1f%s\n' "$name" "$img"
    done
}

selection=$(
  generate_rofi_list | rofi -dmenu -show-icons \
    -p ' Choose wallpaper' \
    -theme "$THEME_PATH"
)

[ -z "${selection:-}" ] && exit 0

selected_path="$WALL_DIR/$selection"

# 1) Appliquer tout de suite (fallback = tous les écrans)
# Pas besoin de restart hyprpaper.
hyprctl hyprpaper wallpaper ",$selected_path" >/dev/null

# 2) Persister pour le prochain boot (nouvelle syntaxe)
# (Tu peux aussi ajouter des blocs par écran si tu veux.)
cat >"$CONFIG_PATH" <<EOF
wallpaper {
  monitor =
  path = $selected_path
}
splash = false
EOF

# 3) Mettre à jour hyprlock.conf (sans casser le symlink)
new_content=""
inside_background=0

while IFS= read -r line; do
  trimmed="$(echo "$line" | sed 's/^[[:space:]]*//')"

  if [[ "$trimmed" == "background {" ]]; then
    inside_background=1
  elif [[ "$trimmed" == "}" && $inside_background -eq 1 ]]; then
    inside_background=0
  fi

  if [[ $inside_background -eq 1 && "$trimmed" == path\ =* ]]; then
    indent="$(echo "$line" | grep -o '^[[:space:]]*' || true)"
    line="${indent}path = $selected_path"
  fi

  new_content+="$line"$'\n'
done <"$LOCK_CONFIG"

printf "%s" "$new_content" >"$LOCK_CONFIG"
