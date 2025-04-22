#!/bin/bash

CONFIG_FILE="$HOME/.config/hypr/monitors.conf"

[[ "$1" != "home" && "$1" != "work" ]] && {
  echo "Usage: $0 [home|work]"
  exit 1
}

mode="$1"
new_content=$(awk -v mode="$mode" '
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
' "$CONFIG_FILE")

# ✍️ Écriture in-place (le fichier reste intact, le symlink aussi)
printf "%s\n" "$new_content" >"$CONFIG_FILE"
