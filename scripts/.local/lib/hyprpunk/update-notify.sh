#!/usr/bin/env bash
# Tells you once per session when HyprPunk has an update, started by autostart.lua,
# unless you turned it off in the settings (updatesctl.sh). The notification's button
# runs the update in your terminal.
#   update-notify.sh
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")

"$script_dir/updatesctl.sh" get | grep -qx 'hyprpunk=true' || exit 0
# At login the network may still be coming up
nm-online -q -t 60 || exit 0
"$HOME/.dotfiles/install.sh" check >/dev/null || exit 0

action="$(notify-send -a HyprPunk -i system-software-update -A update=Update \
  "HyprPunk update" "A new version of HyprPunk is waiting.")"
[[ "$action" == "update" ]] || exit 0
exec "$script_dir/updatesctl.sh" run
