#!/usr/bin/env bash
# Saves how the mouse and the touchpad behave: the pointer's speed and acceleration,
# which way they scroll, whether focus follows the pointer, and the touchpad's taps and
# scrolling. Hyprland reads the file (input_state.lua) and is reloaded to follow it. The
# settings window and `hyprpunk input` come here; turning the touchpad off is
# touchpadctl.sh's.
#   inputctl.sh get                           every setting, as key=value
#   inputctl.sh set sensitivity <-1…1>        the pointer's speed, 0 as the mouse has it
#   inputctl.sh set acceleration <adaptive|flat>
#   inputctl.sh set focus <true|false>        focus follows the pointer
#   inputctl.sh set mouse.natural <true|false>
#   inputctl.sh set touchpad.natural|touchpad.tap|touchpad.typing <true|false>
#   inputctl.sh set touchpad.scroll <0.5|1|1.5|2>
#   inputctl.sh ensure                        fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/input.conf"

declare -A DEFAULTS=(
  [sensitivity]=0
  [acceleration]=adaptive
  [focus]=true
  [mouse.natural]=false
  [touchpad.natural]=false
  [touchpad.tap]=true
  [touchpad.typing]=true
  [touchpad.scroll]=1
)
KEYS=(sensitivity acceleration focus mouse.natural touchpad.natural touchpad.tap touchpad.typing touchpad.scroll)

valid() {
  case "$1" in
  sensitivity) [[ "$2" =~ ^-?(0|1|0\.[0-9]+)$ ]] ;;
  acceleration) [[ "$2" =~ ^(adaptive|flat)$ ]] ;;
  touchpad.scroll) [[ "$2" =~ ^(0\.5|1|1\.5|2)$ ]] ;;
  *) [[ "$2" == "true" || "$2" == "false" ]] ;;
  esac
}

settings_main "$@"
# Hyprland reads it on each reload
if [[ "${1:-}" == "set" ]]; then
  hyprctl reload >/dev/null 2>&1 || true
fi
