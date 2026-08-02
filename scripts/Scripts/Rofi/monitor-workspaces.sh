#!/usr/bin/env bash
set -u

source "$HOME/Scripts/Rofi/monitor-common.sh"

outputs="$(monitor_outputs)" || exit 1
options=""
while IFS= read -r output; do
  slot="$("$DISPLAYCTL" slot-get "$output")"
  options+="${output} · Number ${slot}"$'\n'
done <<<"$outputs"

choice="$(monitor_choose "󰖲 Workspace output" "${options%$'\n'}")"
[[ -z "$choice" ]] && monitor_back_to_main
output="${choice%% · Number *}"

exec "$SCRIPT_DIR/monitor-workspaces-value.sh" "$output"
