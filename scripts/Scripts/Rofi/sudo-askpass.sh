#!/usr/bin/env bash
set -euo pipefail

THEME_PATH="$HOME/.config/rofi/catppuccin-script.rasi"

if password="$(rofi -dmenu -password \
  -p "󰌾 Password" \
  -theme "$THEME_PATH")"; then
  if [[ -n "${SDDM_ASKPASS_STATE:-}" ]]; then
    printf 'provided\n' >>"$SDDM_ASKPASS_STATE"
  fi
  printf '%s\n' "$password"
else
  if [[ -n "${SDDM_ASKPASS_STATE:-}" ]]; then
    printf 'cancelled\n' >>"$SDDM_ASKPASS_STATE"
  fi
  exit 1
fi
