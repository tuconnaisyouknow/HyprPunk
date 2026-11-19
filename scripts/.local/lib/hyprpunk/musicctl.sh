#!/usr/bin/env bash
# Saves the music's settings: the players the shell follows (any by default, or only the
# ones named, as `playerctl -l` names them without their instance), the island's equalizer
# dancing while it plays or standing still, and the wave at the bottom of the desktop and
# the lock screen on or off. Both keep the screen redrawing while they move, which costs a
# laptop's GPU. The shell watches the file (Players.qml, Equalizer.qml, VisualizerShell.qml,
# Lock.qml); its settings window and `hyprpunk music` come here.
#   musicctl.sh get                                every setting, as key=value
#   musicctl.sh set sources <spotify,firefox|"">   "" follows any player
#   musicctl.sh set equalizer <true|false>
#   musicctl.sh set wave <true|false>
#   musicctl.sh ensure                             fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/music.conf"

declare -A DEFAULTS=(
  [sources]=""
  [equalizer]=true
  [wave]=true
)
KEYS=(sources equalizer wave)

valid() {
  case "$1" in
  sources) [[ -z "$2" || "$2" =~ ^[A-Za-z0-9_-]+(,[A-Za-z0-9_-]+)*$ ]] ;;
  equalizer | wave) [[ "$2" == "true" || "$2" == "false" ]] ;;
  esac
}

settings_main "$@"
