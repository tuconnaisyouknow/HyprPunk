#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output>"
  exit 1
fi

source "$HOME/Scripts/Rofi/monitor-common.sh"

output="$1"
resolutions="$("$DISPLAYCTL" resolutions "$output")" || exit 1
resolution="$(monitor_choose "󰹑 Resolution · $output" "$(printf 'Automatic (preferred)\n%s\n' "$resolutions")")"

if [[ -z "$resolution" ]]; then
  exec "$SCRIPT_DIR/monitor-resolution.sh"
fi

if [[ "$resolution" == *Automatic* ]]; then
  "$DISPLAYCTL" auto "$output"
else
  "$DISPLAYCTL" resolution "$output" "$resolution"
fi
