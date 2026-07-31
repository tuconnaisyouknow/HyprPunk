#!/usr/bin/env bash
set -u

source "$HOME/Scripts/Rofi/monitor-common.sh"

outputs="$(monitor_outputs)" || exit 1
if [[ "$(wc -l <<<"$outputs")" -lt 2 ]]; then
  notify-send -u normal "At least two active outputs are required."
  monitor_back_to_main
fi

output="$(monitor_choose "󰍺 Output to move" "$outputs")"
[[ -z "$output" ]] && monitor_back_to_main

exec "$SCRIPT_DIR/monitor-position-reference.sh" "$output"
