#!/usr/bin/env bash
# Saves the battery's warnings: the level where the island warns you it's low, the one
# where it's critical, and what the computer does a minute after that if you don't plug
# it in. The shell watches the file (Bar.qml, CriticalBattery.qml); its settings window
# and `hyprpunk battery` come here. The charge limit is the control center's.
#   batteryctl.sh get                                every setting, as key=value
#   batteryctl.sh set low <percent>                  10 to 30
#   batteryctl.sh set critical <percent>             2 to 7, under the low one
#   batteryctl.sh set action <none|suspend|poweroff>
#   batteryctl.sh ensure                             fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/battery.conf"

declare -A DEFAULTS=(
  [low]=20
  [critical]=5
  [action]=suspend
)
KEYS=(low critical action)

# The ranges don't meet, so the critical level always stays under the low one
valid() {
  case "$1" in
  low) [[ "$2" =~ ^[0-9]+$ ]] && ((10#$2 >= 10 && 10#$2 <= 30)) ;;
  critical) [[ "$2" =~ ^[0-9]+$ ]] && ((10#$2 >= 2 && 10#$2 <= 7)) ;;
  action) [[ "$2" =~ ^(none|suspend|poweroff)$ ]] ;;
  esac
}

settings_main "$@"
