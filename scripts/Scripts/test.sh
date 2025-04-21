#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"

find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) | while read -r img; do
    name=$(basename "$img")
    echo -e "$name\0icon\x1f$img"
done | rofi -dmenu \
    -p "🖼 Wallpapers" \
    -theme-str 'element-icon { size: 64px; } listview { lines: 6; }'

