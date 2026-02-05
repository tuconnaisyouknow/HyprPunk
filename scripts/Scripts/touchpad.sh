#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/hypr/touchpad.conf"

# Résout la cible réelle du symlink (si c'est un vrai fichier, ça renvoie lui-même)
TARGET="$(readlink -f "$CONFIG_FILE")"

enabled="$(grep -Eo 'enabled[[:space:]]*=[[:space:]]*[01]' "$TARGET" | head -n1 || true)"

if [[ "$enabled" == *"= 0" ]]; then
  perl -pi -e 's/(enabled\s*=\s*)0/${1}1/' "$TARGET"
  notify-send -u low -i /usr/share/icons/Papirus-Dark/32x32/devices/gnome-dev-mouse-optical.svg 'Mouse toggle' '✅ Enabled'
else
  perl -pi -e 's/(enabled\s*=\s*)1/${1}0/' "$TARGET"
  notify-send -u low -i /usr/share/icons/Papirus-Dark/32x32/devices/gnome-dev-mouse-optical.svg 'Mouse toggle' '❌ Disabled'
fi
