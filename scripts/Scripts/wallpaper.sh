#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"
CONFIG_PATH="$HOME/.config/hypr/hyprpaper.conf"
LOCK_CONFIG="$HOME/.config/hypr/hyprlock.conf"

generate_rofi_list() {
  find -L "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | while read -r img; do
    name=$(basename "$img")
    echo -e "$name\0icon\x1f$img"
  done
}

selection=$(
  generate_rofi_list | rofi -dmenu -show-icons \
    -p "🎨 Choose wallpaper " \
    -theme-str '* {font: "JetBrainsMono Nerd Font 10";}' \
    -theme-str 'element-icon { size: 64px; }' \
    -theme-str 'listview { lines: 10; }'
)

[ -z "$selection" ] && exit 0

selected_path="$WALL_DIR/$selection"

# 🔧 Modifier hyprpaper.conf
echo "preload = $selected_path" >"$CONFIG_PATH"
echo "wallpaper = , $selected_path" >>"$CONFIG_PATH"

# 🔧 Modifier uniquement le path dans le bloc background {} sans casser le symlink
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
    indent="$(echo "$line" | grep -o '^[[:space:]]*')"
    line="${indent}path = $selected_path"
  fi

  new_content+="$line"$'\n'
done <"$LOCK_CONFIG"

# 🔒 Écrire dans le même fichier sans recréer : symlink préservé
printf "%s" "$new_content" >"$LOCK_CONFIG"

# 🔁 Redémarrer hyprpaper
pkill hyprpaper
hyprpaper &
disown
