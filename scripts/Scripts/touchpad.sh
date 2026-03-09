#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/hypr/touchpad.conf"
TARGET="$(readlink -f "$CONFIG_FILE")"

# Récupère la première occurrence: enabled = 0 ou enabled = 1
enabled_line="$(grep -E '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*[01]' "$TARGET" | head -n1 || true)"

if [[ -z "${enabled_line}" ]]; then
  echo "Erreur: impossible de trouver 'enabled = 0/1' dans $TARGET" >&2
  exit 1
fi

# Extrait la valeur 0/1
enabled_val="$(echo "$enabled_line" | grep -Eo '[01]$')"

osd() {
  # Si swayosd ne répond pas, on ne casse pas le script
  swayosd-client --custom-message "$1" --custom-icon input-touchpad 2>/dev/null || true
}

if [[ "$enabled_val" == "0" ]]; then
  # OFF -> ON
  perl -pi -e 's/^(\s*enabled\s*=\s*)0(\s*)$/${1}1$2/' "$TARGET"
  osd "Touchpad On"
else
  # ON -> OFF
  perl -pi -e 's/^(\s*enabled\s*=\s*)1(\s*)$/${1}0$2/' "$TARGET"
  osd "Touchpad Off"
fi
