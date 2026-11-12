#!/usr/bin/env bash
# Gets you through a network's sign-in page (hotels, trains), started by the shell as
# NetworkManager's view of the internet changes. A VPN hides that page: its tunnel goes
# nowhere until you've signed in, so the network only looks limited. Then you're asked
# before the VPN steps aside, and it comes back once you're online.
#   captive-portal.sh portal    the network wants you to sign in: offers to open its page
#   captive-portal.sh limited   no internet with a VPN up on Wi-Fi: offers to sign in without it
#   captive-portal.sh online    puts back the VPNs taken down to sign in
set -euo pipefail

# Which VPNs stepped aside, forgotten when you restart
PAUSED="${XDG_RUNTIME_DIR:-/run/user/$UID}/hyprpunk/paused-vpns"

usage() {
  echo "Usage: $0 {portal|limited|online}"
}

# NetworkManager's own check page: the one the network was caught intercepting
check_uri() {
  NetworkManager --print-config 2>/dev/null |
    awk -F= '/^\[/ { section = $0 } section == "[connectivity]" && $1 == "uri" { print substr($0, 5); exit }'
}

# The VPNs up right now, by uuid
active_vpns() {
  nmcli -t -f UUID,TYPE connection show --active | awk -F: '$2 == "wireguard" || $2 == "vpn" { print $1 }'
}

on_wifi() {
  nmcli -t -f TYPE connection show --active | grep -qx 802-11-wireless
}

restore_vpns() {
  local uuid
  [[ -f "$PAUSED" ]] || return 0
  while IFS= read -r uuid; do
    nmcli connection up uuid "$uuid" >/dev/null 2>&1 || true
  done <"$PAUSED"
  rm -f "$PAUSED"
}

portal() {
  local uri action
  uri="$(check_uri)"
  [[ -n "$uri" ]] || exit 0
  action="$(notify-send -a HyprPunk -i network-wireless -A open="Sign In" \
    "Sign in to the network" "This network wants you to sign in before you can go online.")"
  [[ "$action" == "open" ]] || exit 0
  exec xdg-open "$uri"
}

limited() {
  local action vpns uuid
  vpns="$(active_vpns)"
  [[ -n "$vpns" ]] && on_wifi || exit 0
  action="$(notify-send -a HyprPunk -i network-wireless -A signin="Sign In Without VPN" \
    "No internet through the VPN" "This network may hide a sign-in page behind your VPN.")"
  [[ "$action" == "signin" ]] || exit 0

  mkdir -p "${PAUSED%/*}"
  printf '%s\n' "$vpns" >"$PAUSED"
  while IFS= read -r uuid; do
    nmcli connection down uuid "$uuid" >/dev/null 2>&1 || true
  done <<<"$vpns"

  # A sign-in page shows up on its own (portal); anything else, the VPNs come back
  [[ "$(nmcli networking connectivity check)" == "portal" ]] || restore_vpns
}

case "${1:-}" in
portal) portal ;;
limited) limited ;;
online) restore_vpns ;;
*)
  usage >&2
  exit 1
  ;;
esac
