#!/usr/bin/env bash
# Tells you a network wants you to sign in before it lets you online (hotels, trains),
# started by the shell when NetworkManager finds its check page replaced. The button
# opens that check page in your browser, which the network sends on to its sign-in.
#   captive-portal.sh
set -euo pipefail

# NetworkManager's own check page: the one the network was caught intercepting
uri="$(NetworkManager --print-config 2>/dev/null |
  awk -F= '/^\[/ { section = $0 } section == "[connectivity]" && $1 == "uri" { print substr($0, 5); exit }')"
[[ -n "$uri" ]] || exit 0

action="$(notify-send -a HyprPunk -i network-wireless -A open="Sign In" \
  "Sign in to the network" "This network wants you to sign in before you can go online.")"
[[ "$action" == "open" ]] || exit 0
exec xdg-open "$uri"
