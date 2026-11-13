#!/usr/bin/env bash
# Saves how updates reach you: the notification at login when HyprPunk has one, and the
# bar's count of package updates, how often it asks. Both ways to update HyprPunk from
# the shell come here too, the notification's button (update-notify.sh) and the
# settings window's. The settings window and `hyprpunk updates` change it.
#   updatesctl.sh get                          every setting, as key=value
#   updatesctl.sh set hyprpunk <true|false>    the notification at login
#   updatesctl.sh set packages <true|false>    the bar's count of package updates
#   updatesctl.sh set interval <minutes>       how often it counts them again
#   updatesctl.sh version                      the installed HyprPunk's date and commit
#   updatesctl.sh run                          updates HyprPunk in your terminal
#   updatesctl.sh ensure                       fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/updates.conf"
DOTFILES_DIR="$HOME/.dotfiles"

declare -A DEFAULTS=(
  [hyprpunk]=true
  [packages]=true
  [interval]=15
)
KEYS=(hyprpunk packages interval)

valid() {
  case "$1" in
  hyprpunk | packages) [[ "$2" == "true" || "$2" == "false" ]] ;;
  interval) [[ "$2" =~ ^(15|60|180|360)$ ]] ;;
  esac
}

case "${1:-}" in
version) exec git -C "$DOTFILES_DIR" log -1 --format='%cs %h' ;;
# The terminal stays open at the end so you can read how it went. The installer reaches
# the inner shell as an argument, so its path is never parsed.
run)
  # shellcheck disable=SC2016
  exec "${TERMINAL:-kitty}" -e sh -c '"$1" update; printf "\nPress Enter to close."; read -r _' \
    sh "$DOTFILES_DIR/install.sh"
  ;;
*) settings_main "$@" ;;
esac
