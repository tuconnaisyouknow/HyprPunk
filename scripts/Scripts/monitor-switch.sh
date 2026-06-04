#!/bin/bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/hypr/monitors.lua"
TARGET="$(readlink -f "$CONFIG_FILE")"

usage() {
  echo "Usage: $0 [home|work|toggle]"
  exit 1
}

[[ $# -ne 1 ]] && usage
[[ "$1" != "home" && "$1" != "work" && "$1" != "toggle" ]] && usage

# Detecte le mode actif en regardant la variable ACTIVE_MODE.
detect_active_mode() {
  local active_line

  active_line="$(grep -E '^[[:space:]]*local[[:space:]]+ACTIVE_MODE[[:space:]]*=[[:space:]]*"(home|work)"[[:space:]]*$' "$TARGET" | head -n1 || true)"

  if [[ -z "$active_line" ]]; then
    echo "none"
    return 0
  fi

  echo "$active_line" | grep -Eo '(home|work)' | tail -n1
}

mode="$1"
if [[ "$mode" == "toggle" ]]; then
  active="$(detect_active_mode)"
  case "$active" in
  home) mode="work" ;;
  work) mode="home" ;;
  none)
    echo "Error: no active monitor config detected in monitors.lua."
    echo "Run explicitly once: $0 home  /  $0 work"
    exit 2
    ;;
  *)
    echo "Error: unexpected detected state: $active"
    exit 2
    ;;
  esac
fi

new_content="$(awk -v mode="$mode" '
  /^[[:space:]]*local[[:space:]]+ACTIVE_MODE[[:space:]]*=/ {
    print "local ACTIVE_MODE = \"" mode "\""
    next
  }

  { print }
' "$TARGET")"

# --- Ecriture atomique (evite fichier vide/partiel pendant le reload Hyprland) ---
DIR="$(dirname "$TARGET")"
TMP="$(mktemp --tmpdir="$DIR" monitors.lua.XXXXXX)"

printf '%s\n' "$new_content" >"$TMP"
mv -f "$TMP" "$TARGET"

hyprctl reload >/dev/null 2>&1 || true
exit 0
