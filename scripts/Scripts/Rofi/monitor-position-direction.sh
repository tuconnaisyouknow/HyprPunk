#!/usr/bin/env bash
set -u

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <output> <reference>"
  exit 1
fi

source "$HOME/Scripts/Rofi/monitor-common.sh"

output="$1"
reference="$2"
direction="$(monitor_choose "󰍺 Position · $output" $' Left\n Right\n Above\n Below')"

if [[ -z "$direction" ]]; then
  exec "$SCRIPT_DIR/monitor-position-reference.sh" "$output"
fi

case "$direction" in
*Left*) direction="left" ;;
*Right*) direction="right" ;;
*Above*) direction="above" ;;
*Below*) direction="below" ;;
*)
  notify-send -u normal "This option doesn't exist."
  exit 1
  ;;
esac

if ! error="$("$DISPLAYCTL" position "$output" "$direction" "$reference" 2>&1)"; then
  notify-send -u normal "Unable to position $output" "$error"
  exit 1
fi
