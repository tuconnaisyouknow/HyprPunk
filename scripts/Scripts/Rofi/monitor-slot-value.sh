#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output>"
  exit 1
fi

source "$HOME/Scripts/Rofi/monitor-common.sh"

output="$1"
current="$("$DISPLAYCTL" slot-get "$output")"
slots="$(seq 1 10)"
slot="$(monitor_choose "󰓡 Number · $output · current $current" "$slots")"

if [[ -z "$slot" ]]; then
  exec "$SCRIPT_DIR/monitor-slot.sh"
fi

if ! error="$("$DISPLAYCTL" slot "$output" "$slot" 2>&1)"; then
  notify-send -u normal "Unable to change output order" "$error"
  exit 1
fi
