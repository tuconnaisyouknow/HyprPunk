#!/usr/bin/env bash
# Saves the night light: off, always on, or on from one hour to another, and how warm it
# makes the screens. The shell watches the file and runs hyprsunset while the screens
# should be warm (NightLight.qml); its settings window and `hyprpunk nightlight` come here.
#   nightlightctl.sh get                         every setting, as key=value
#   nightlightctl.sh set mode <off|on|schedule>
#   nightlightctl.sh set temperature <kelvin>    lower is warmer, 1000 to 6500
#   nightlightctl.sh set from|to <hour>          the schedule, 0 to 23
#   nightlightctl.sh ensure                      fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/nightlight.conf"

declare -A DEFAULTS=(
  [mode]=off
  [temperature]=4500
  [from]=21
  [to]=7
)
KEYS=(mode temperature from to)

valid() {
  case "$1" in
  mode) [[ "$2" =~ ^(off|on|schedule)$ ]] ;;
  temperature) [[ "$2" =~ ^[0-9]+$ ]] && ((10#$2 >= 1000 && 10#$2 <= 6500)) ;;
  from | to) [[ "$2" =~ ^[0-9]+$ ]] && ((10#$2 <= 23)) ;;
  esac
}

settings_main "$@"
