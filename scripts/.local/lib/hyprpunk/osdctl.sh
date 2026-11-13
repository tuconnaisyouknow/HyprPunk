#!/usr/bin/env bash
# Saves what the island tells you as it happens (the OSD): which changes show, and how
# long they stay. The battery's warnings always show. The shell watches the file
# (Bar.qml); its settings window and `hyprpunk osd` come here.
#   osdctl.sh get                              every setting, as key=value
#   osdctl.sh set <change> <true|false>        volume, microphone, brightness, keys,
#                                              power, airpods or screenshots
#   osdctl.sh set duration <short|normal|long>
#   osdctl.sh ensure                           fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/osd.conf"

declare -A DEFAULTS=(
  [volume]=true
  [microphone]=true
  [brightness]=true
  [keys]=true
  [power]=true
  [airpods]=true
  [screenshots]=true
  [duration]=normal
)
KEYS=(volume microphone brightness keys power airpods screenshots duration)

valid() {
  case "$1" in
  duration) [[ "$2" =~ ^(short|normal|long)$ ]] ;;
  *) [[ "$2" == "true" || "$2" == "false" ]] ;;
  esac
}

settings_main "$@"
