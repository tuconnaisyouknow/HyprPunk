#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output>"
  exit 1
fi

source "$HOME/Scripts/Rofi/monitor-common.sh"

output="$1"
outputs="$(monitor_outputs)" || exit 1
references="$(printf '%s\n' "$outputs" | awk -v output="$output" '$0 != output')"
reference="$(monitor_choose "󰍺 Relative to" "$references")"

if [[ -z "$reference" ]]; then
  exec "$SCRIPT_DIR/monitor-position.sh"
fi

exec "$SCRIPT_DIR/monitor-position-direction.sh" "$output" "$reference"
