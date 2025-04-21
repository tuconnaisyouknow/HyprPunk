#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"
CONFIG_PATH="$HOME/.config/hypr/hyprpaper.conf"

generate_rofi_list() {
  find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | while read -r img; do
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

echo "preload = $selected_path" >"$CONFIG_PATH"
echo "wallpaper = , $selected_path" >>"$CONFIG_PATH"

pkill hyprpaper
hyprpaper &
disown
