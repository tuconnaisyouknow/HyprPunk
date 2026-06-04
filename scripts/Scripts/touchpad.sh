#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/hypr/touchpad.lua"
TARGET="$(readlink -f "$CONFIG_FILE")"

# Recupere la premiere occurrence: local TOUCHPAD_ENABLED = true ou false
enabled_line="$(grep -E '^[[:space:]]*local[[:space:]]+TOUCHPAD_ENABLED[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*$' "$TARGET" | head -n1 || true)"

if [[ -z "${enabled_line}" ]]; then
  echo "Erreur: impossible de trouver 'local TOUCHPAD_ENABLED = true|false' dans $TARGET" >&2
  exit 1
fi

# Extrait la valeur true/false
enabled_val="$(echo "$enabled_line" | grep -Eo '(true|false)$')"

osd() {
  # Si swayosd ne repond pas, on ne casse pas le script
  swayosd-client --custom-message "$1" --custom-icon input-touchpad 2>/dev/null || true
}

if [[ "$enabled_val" == "false" ]]; then
  # OFF -> ON
  perl -0pi -e 's/^[ \t]*local\s+TOUCHPAD_ENABLED\s*=\s*false[ \t]*$/local TOUCHPAD_ENABLED = true/m' "$TARGET"
  osd "Touchpad On"
else
  # ON -> OFF
  perl -0pi -e 's/^[ \t]*local\s+TOUCHPAD_ENABLED\s*=\s*true[ \t]*$/local TOUCHPAD_ENABLED = false/m' "$TARGET"
  osd "Touchpad Off"
fi

hyprctl reload >/dev/null 2>&1 || true
