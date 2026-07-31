#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output>"
  exit 1
fi

source "$HOME/Scripts/Rofi/monitor-common.sh"

output="$1"
options="$(printf '%s\n' "Automatic" "1×" "1.25×" "1.5×" "1.75×" "2×")"
scale="$(monitor_choose "󰩨 Scale · $output" "$options")"

if [[ -z "$scale" ]]; then
  exec "$SCRIPT_DIR/monitor-scale.sh"
fi

if [[ "$scale" == "Automatic" ]]; then
  scale="auto"
else
  scale="${scale%×}"
fi

"$DISPLAYCTL" scale "$output" "$scale"
