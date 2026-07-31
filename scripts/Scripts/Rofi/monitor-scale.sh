#!/usr/bin/env bash
set -u

source "$HOME/Scripts/Rofi/monitor-common.sh"

outputs="$(monitor_outputs)" || exit 1
output="$(monitor_choose "󰍹 Output" "$outputs")"
[[ -z "$output" ]] && monitor_back_to_main

exec "$SCRIPT_DIR/monitor-scale-value.sh" "$output"
