#!/bin/bash

# Fichier à modifier (remplace ce chemin si besoin)
CONFIG_FILE="/home/tuconnais/.config/hypr/monitors.conf"

if [[ "$1" != "home" && "$1" != "work" ]]; then
  echo "Usage: $0 [home|work]"
  exit 1
fi

# On lit le fichier et modifie les lignes
awk -v mode="$1" '
/^# Home/ { home=1; work=0; print; next }
/^# Work/ { home=0; work=1; print; next }

home {
  if (mode == "home") {
    sub(/^#/, ""); print
  } else {
    if ($0 !~ /^#/) $0="#" $0; print
  }
  next
}

work {
  if (mode == "work") {
    sub(/^#/, ""); print
  } else {
    if ($0 !~ /^#/) $0="#" $0; print
  }
  next
}

{ print }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
