#!/usr/bin/env bash
# Saves how the music shows: the bar's cover spinning like a record while it plays,
# still, or left out for a plain record, and the wave at the bottom of the desktop and
# the lock screen on or off. Both keep the screen redrawing while they move, which
# costs a laptop's GPU. The shell watches the file (MusicPill.qml, VisualizerShell.qml,
# Lock.qml); its settings window and `hyprpunk music` come here.
#   musicctl.sh get                                every setting, as key=value
#   musicctl.sh set cover <spinning|still|off>
#   musicctl.sh set wave <true|false>
#   musicctl.sh ensure                             fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/music.conf"

declare -A DEFAULTS=(
  [cover]=spinning
  [wave]=true
)
KEYS=(cover wave)

valid() {
  case "$1" in
  cover) [[ "$2" == "spinning" || "$2" == "still" || "$2" == "off" ]] ;;
  wave) [[ "$2" == "true" || "$2" == "false" ]] ;;
  esac
}

settings_main "$@"
