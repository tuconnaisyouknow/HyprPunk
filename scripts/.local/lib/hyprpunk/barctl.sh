#!/usr/bin/env bash
# Saves how the bar looks: the bar with the pills it keeps, or the island alone, which
# opens under the pointer onto your workspaces and the control center's icons. The island
# always stays, and alone it shows the updates as a chip. A pill you hide keeps its card,
# opened by its shortcut. The shell watches the file (Bar.qml); its
# settings window and `hyprpunk bar` come here.
#   barctl.sh get                                every setting, as key=value
#   barctl.sh set layout <bar|island>
#   barctl.sh set <pill> <true|false>            workspaces, monitor, updates or control
#   barctl.sh ensure                             fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/bar.conf"

declare -A DEFAULTS=(
  [layout]=bar
  [workspaces]=true
  [monitor]=true
  [updates]=true
  [control]=true
)
KEYS=(layout workspaces monitor updates control)

valid() {
  case "$1" in
  layout) [[ "$2" == "bar" || "$2" == "island" ]] ;;
  *) [[ "$2" == "true" || "$2" == "false" ]] ;;
  esac
}

settings_main "$@"
