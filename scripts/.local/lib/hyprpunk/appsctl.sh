#!/usr/bin/env bash
# Saves the apps HyprPunk opens for you: the terminal (Super+Enter, and $TERMINAL for
# every app and the shell), the browser, the file manager and the music app, each as
# the command that starts it. Hyprland reads the file (apps_state.lua) and is reloaded
# to follow it; your personal/keybindings.lua still wins. Given its desktop entry, the
# browser and the file manager also become the ones links and folders open in. The
# settings window and `hyprpunk apps` come here.
#   appsctl.sh get                                      every app, as key=value
#   appsctl.sh set <terminal|browser|files|music> <command> [desktop entry]
#   appsctl.sh ensure                                   fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/apps.conf"

# As keybindings.lua has them
declare -A DEFAULTS=(
  [terminal]=kitty
  [browser]=brave
  [files]=thunar
  [music]=spotify-launcher
)
KEYS=(terminal browser files music)

# A command on one line
valid() {
  [[ -n "$2" && "$2" != *$'\n'* ]]
}

# What opens links and folders, for the apps that ask the system
make_default() {
  case "$1" in
  browser) xdg-settings set default-web-browser "$2" ;;
  files) xdg-mime default "$2" inode/directory ;;
  esac
}

case "${1:-}" in
set)
  settings_main "${@:1:3}"
  if (($# == 4)); then
    make_default "$2" "$4"
  fi
  hyprctl reload >/dev/null 2>&1 || true
  ;;
*) settings_main "$@" ;;
esac
