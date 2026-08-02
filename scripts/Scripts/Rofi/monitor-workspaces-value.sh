#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output>"
  exit 1
fi

source "$HOME/Scripts/Rofi/monitor-common.sh"

output="$1"
original="$("$DISPLAYCTL" workspace-get "$output")"
pending="$original"

while true; do
  owners="$("$DISPLAYCTL" workspace-owners)"
  options="$(
    {
      seq 1 10
      tr ',' '\n' <<<"$pending"
      cut -f1 <<<"$owners"
    } |
      awk 'NF && /^[0-9]+$/ && !seen[$1]++ { print $1 }' |
      sort -n |
      awk -v pending=",$pending," -v owners="$owners" -v selected_output="$output" '
        BEGIN {
          count = split(owners, lines, "\n")
          for (i = 1; i <= count; i++) {
            separator = index(lines[i], "\t")
            if (separator > 0) {
              workspace = substr(lines[i], 1, separator - 1)
              owner[workspace] = substr(lines[i], separator + 1)
            }
          }
        }
        index(pending, "," $1 ",") { print "● Workspace " $1; next }
        owner[$1] != "" && owner[$1] != selected_output {
          print "○ Workspace " $1 " · " owner[$1]
          next
        }
        { print "○ Workspace " $1 }
      '
  )"
  selection="$(
    {
      printf '%s\n' "$options"
      printf '%s\n' "󰆴 Clear all"
      printf '%s\n' "✓ Done"
    } | rofi -i -dmenu \
      -p "󰖲 Workspaces · $output · type a number" \
      -theme "$THEME_PATH"
  )"

  if [[ -z "$selection" ]]; then
    exec "$SCRIPT_DIR/monitor-workspaces.sh"
  fi

  if [[ "$selection" == "✓ Done" ]]; then
    if [[ "$pending" != "$original" ]]; then
      [[ -n "$pending" ]] || pending="none"
      if ! error="$("$DISPLAYCTL" workspace-set "$output" "$pending" 2>&1)"; then
        notify-send -u normal "Unable to assign workspaces" "$error"
        exit 1
      fi
    fi
    exit 0
  fi

  if [[ "$selection" == "󰆴 Clear all" ]]; then
    pending=""
    continue
  fi

  if [[ "$selection" =~ ^[●○][[:space:]]Workspace[[:space:]]([1-9][0-9]*)([[:space:]]·.*)?$ ]]; then
    workspace="${BASH_REMATCH[1]}"
  elif [[ "$selection" =~ ^[1-9][0-9]*$ ]]; then
    workspace="$selection"
  else
    notify-send -u normal "Invalid workspace" "Enter a positive workspace number."
    continue
  fi

  if [[ ",$pending," == *",$workspace,"* ]]; then
    pending="$(
      tr ',' '\n' <<<"$pending" |
        awk -v workspace="$workspace" '$1 != workspace && NF' |
        paste -sd, -
    )"
  else
    pending="${pending:+$pending,}$workspace"
  fi
done
