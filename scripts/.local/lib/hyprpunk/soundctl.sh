#!/usr/bin/env bash
# Saves how the volume moves: how much a volume key changes it, and the limit nothing in
# the shell raises it past, to keep your ears safe. A new limit brings a louder volume
# down to it. The volume keys come here
# (keybindings.lua), and the control center's slider follows the limit too. The settings
# window and `hyprpunk sound` change it.
#   soundctl.sh get                        every setting, as key=value
#   soundctl.sh set step <2|5|10>          percent per key press
#   soundctl.sh set limit <50…100>         the highest volume, in percent
#   soundctl.sh raise | lower              the volume keys
#   soundctl.sh ensure                     fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/sound.conf"

declare -A DEFAULTS=(
  [step]=5
  [limit]=100
)
KEYS=(step limit)

valid() {
  case "$1" in
  step) [[ "$2" =~ ^(2|5|10)$ ]] ;;
  limit) [[ "$2" =~ ^[0-9]+$ ]] && ((10#$2 >= 50 && 10#$2 <= 100)) ;;
  esac
}

# wpctl takes the limit as a fraction: 70 becomes 0.70
limit_fraction() {
  local limit="${SETTINGS[limit]}"
  printf '%d.%02d' $((limit / 100)) $((limit % 100))
}

case "${1:-}" in
raise)
  settings_load
  exec wpctl set-volume -l "$(limit_fraction)" @DEFAULT_AUDIO_SINK@ "${SETTINGS[step]}%+"
  ;;
lower)
  settings_load
  exec wpctl set-volume @DEFAULT_AUDIO_SINK@ "${SETTINGS[step]}%-"
  ;;
# Raising by nothing up to the limit lowers a louder volume, and leaves a quieter one
set)
  settings_main "$@"
  if [[ "$2" == "limit" ]]; then
    settings_load
    wpctl set-volume -l "$(limit_fraction)" @DEFAULT_AUDIO_SINK@ 0%+
  fi
  ;;
*) settings_main "$@" ;;
esac
