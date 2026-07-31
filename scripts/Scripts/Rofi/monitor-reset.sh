#!/usr/bin/env bash
set -u

source "$HOME/Scripts/Rofi/monitor-common.sh"

confirmation="$(monitor_choose "󰑓 Reset monitor settings?" $'Cancel\nReset to defaults')"

if [[ -z "$confirmation" || "$confirmation" == "Cancel" ]]; then
  monitor_back_to_main
fi

if [[ "$confirmation" == "Reset to defaults" ]]; then
  "$DISPLAYCTL" reset
  notify-send -u normal "Monitor settings reset to defaults."
else
  notify-send -u normal "This option doesn't exist."
fi
