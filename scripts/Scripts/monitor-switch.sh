#!/bin/bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/hypr/monitors.conf"

usage() {
  echo "Usage: $0 [home|work|toggle]"
  exit 1
}

[[ $# -ne 1 ]] && usage
[[ "$1" != "home" && "$1" != "work" && "$1" != "toggle" ]] && usage

# Détecte le mode actif en regardant s'il existe au moins une ligne "monitor="
# non commentée dans chaque bloc (# Home / # Work).
detect_active_mode() {
  awk '
    /^# Home/ { in_home=1; in_work=0; next }
    /^# Work/ { in_home=0; in_work=1; next }

    in_home && $0 ~ /^[[:space:]]*monitor[[:space:]]*=/ && $0 !~ /^[[:space:]]*#/ { home_on=1 }
    in_work && $0 ~ /^[[:space:]]*monitor[[:space:]]*=/ && $0 !~ /^[[:space:]]*#/ { work_on=1 }

    END {
      if (home_on && !work_on) { print "home"; exit 0 }
      if (work_on && !home_on) { print "work"; exit 0 }
      if (home_on && work_on)  { print "ambiguous"; exit 0 }
      print "none"
    }
  ' "$CONFIG_FILE"
}

mode="$1"
if [[ "$mode" == "toggle" ]]; then
  active="$(detect_active_mode)"
  case "$active" in
  home) mode="work" ;;
  work) mode="home" ;;
  ambiguous)
    echo "Error: both Home and Work blocks appear active (non-commented monitor lines in both)."
    echo "Fix monitors.conf or run explicitly: $0 home  /  $0 work"
    exit 2
    ;;
  none)
    echo "Error: no active monitor config detected (no non-commented monitor= lines in Home/Work blocks)."
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
  /^# Home/ { in_home=1; in_work=0; print; next }
  /^# Work/ { in_home=0; in_work=1; print; next }

  in_home {
    if (mode == "home") sub(/^[[:space:]]*# ?/, ""); else if ($0 !~ /^[[:space:]]*#/) $0="#" $0
    print; next
  }

  in_work {
    if (mode == "work") sub(/^[[:space:]]*# ?/, ""); else if ($0 !~ /^[[:space:]]*#/) $0="#" $0
    print; next
  }

  { print }
' "$CONFIG_FILE")"

# --- Écriture atomique (évite fichier vide/partiel pendant le reload Hyprland) ---
TARGET="$(readlink -f "$CONFIG_FILE")"
DIR="$(dirname "$TARGET")"
TMP="$(mktemp --tmpdir="$DIR" monitors.conf.XXXXXX)"

printf '%s\n' "$new_content" >"$TMP"
mv -f "$TMP" "$TARGET"

hyprctl reload >/dev/null 2>&1
exit 0
