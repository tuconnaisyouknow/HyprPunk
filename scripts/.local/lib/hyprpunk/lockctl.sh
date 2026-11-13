#!/usr/bin/env bash
# Saves how the lock screen looks: whether it shows the player and its lyrics, which
# anyone at the screen can see, and whether it blurs in and out of your desktop or
# covers it and leaves it at once, with only the island playing its padlock. The shell
# watches the file (Lock.qml); its settings window and `hyprpunk lock` come here.
#   lockctl.sh get                         every setting, as key=value
#   lockctl.sh set player <true|false>
#   lockctl.sh set animation <true|false>
#   lockctl.sh ensure                      fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/lock.conf"

declare -A DEFAULTS=(
  [player]=true
  [animation]=true
)
KEYS=(player animation)

valid() {
  [[ "$2" == "true" || "$2" == "false" ]]
}

settings_main "$@"
