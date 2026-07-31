#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output>"
  exit 1
fi

source "$HOME/Scripts/Rofi/monitor-common.sh"

output="$1"
frequencies="$("$DISPLAYCTL" frequencies "$output")" || exit 1
if [[ -z "$frequencies" ]]; then
  notify-send -u normal "No refresh rates found for $output."
  exec "$SCRIPT_DIR/monitor-frequency.sh"
fi

options="$(
  while IFS= read -r value; do
    printf '%s Hz\n' "$value"
  done <<<"$frequencies"
)"
frequency="$(monitor_choose "󰓅 Refresh rate · $output" "$options")"

if [[ -z "$frequency" ]]; then
  exec "$SCRIPT_DIR/monitor-frequency.sh"
fi

"$DISPLAYCTL" refresh "$output" "${frequency% Hz}"
