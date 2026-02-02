#!/usr/bin/env bash
set -euo pipefail

raw="$(cliphist list)"
display="$(printf '%s\n' "$raw" | sed 's/^[^[:space:]]\+[[:space:]]\+//')"
idx="$(printf '%s\n' "$display" | rofi -dmenu -i -p ' Clipboard' -format i -theme ~/.config/rofi/catppuccin-list.rasi)"

[ -z "${idx:-}" ] && exit 0

line="$(printf '%s\n' "$raw" | sed -n "$((idx + 1))p")"

printf '%s' "$line" | cliphist decode | wl-copy
