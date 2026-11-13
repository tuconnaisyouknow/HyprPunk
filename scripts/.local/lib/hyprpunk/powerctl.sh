#!/usr/bin/env bash
# Saves when the computer dims, locks and sleeps once you leave it, plugged in and on
# battery, and whether playing media keeps it awake. The shell watches the file and
# acts on it (Idle.qml); its settings window and `hyprpunk power` both come here.
#   powerctl.sh get                      every setting, as key=value
#   powerctl.sh set <key> <value>        a delay in seconds (0 for never), or true|false for media
#   powerctl.sh ensure                   fills in what's missing with the defaults (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/power.conf"

# The keyboard's light goes off first, then the screen dims, locks and the computer sleeps
declare -A DEFAULTS=(
  [plugged.keyboard]=30
  [plugged.dim]=300
  [plugged.lock]=330
  [plugged.suspend]=1800
  [battery.keyboard]=30
  [battery.dim]=300
  [battery.lock]=330
  [battery.suspend]=1800
  [media]=false
)
KEYS=(plugged.keyboard plugged.dim plugged.lock plugged.suspend
  battery.keyboard battery.dim battery.lock battery.suspend media)

valid() {
  if [[ "$1" == "media" ]]; then
    [[ "$2" == "true" || "$2" == "false" ]]
  else
    [[ "$2" =~ ^[0-9]+$ ]]
  fi
}

settings_main "$@"
