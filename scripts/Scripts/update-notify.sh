#!/usr/bin/env bash
# Tells you once per session when HyprPunk has an update, started by autostart.lua.
# The notification's button runs the update in your terminal, which stays open at the
# end so you can read how it went.
#   update-notify.sh
set -euo pipefail

# The repository this script was linked from, wherever you cloned it
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_DIR="$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)"
INSTALLER="$DOTFILES_DIR/install.sh"

# At login the network may still be coming up
nm-online -q -t 60 || exit 0
"$INSTALLER" check >/dev/null || exit 0

action="$(notify-send -a HyprPunk -i system-software-update -A update=Update \
  "HyprPunk update" "A new version of HyprPunk is waiting.")"
[[ "$action" == "update" ]] || exit 0

# The installer reaches the inner shell as an argument, so its path is never parsed
# shellcheck disable=SC2016
exec "${TERMINAL:-kitty}" -e sh -c '"$1" update; printf "\nPress Enter to close."; read -r _' sh "$INSTALLER"
