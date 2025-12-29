#!/bin/bash

CONFIG_FILE="$HOME/.config/hypr/monitors.conf"

[[ "$1" != "home" && "$1" != "work" ]] && {
  echo "Usage: $0 [home|work]"
  exit 1
}

mode="$1"

new_content="$(awk -v mode="$mode" '
  /^# Home/ { in_home=1; in_work=0; print; next }
  /^# Work/ { in_home=0; in_work=1; print; next }

  in_home {
    if (mode == "home") sub(/^#/, ""); else if ($0 !~ /^#/) $0="#" $0
    print; next
  }

  in_work {
    if (mode == "work") sub(/^#/, ""); else if ($0 !~ /^#/) $0="#" $0
    print; next
  }

  { print }
' "$CONFIG_FILE")"

# --- Écriture atomique (évite fichier vide/partiel pendant le reload Hyprland) ---
# Si monitors.conf est un symlink, on écrit dans la cible réelle (le symlink reste intact)
TARGET="$(readlink -f "$CONFIG_FILE")"
DIR="$(dirname "$TARGET")"
TMP="$(mktemp --tmpdir="$DIR" monitors.conf.XXXXXX)"

# Écrit le nouveau contenu dans un fichier temporaire
printf '%s\n' "$new_content" >"$TMP"

# Remplacement atomique
mv -f "$TMP" "$TARGET"

# (Optionnel mais souvent utile) Recharge Hyprland proprement
hyprctl reload >/dev/null 2>&1

exit 0
