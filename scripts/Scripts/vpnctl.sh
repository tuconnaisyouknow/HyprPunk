#!/usr/bin/env bash
# Brings NetworkManager's VPNs up and imports new ones, for the control center's VPN
# tab. Errors go to stderr in one line the shell can show.
#   vpnctl.sh up <uuid>              exits 3 when the VPN wants a password
#   vpnctl.sh up <uuid> --password   the password on stdin, kept out of the process list
#   vpnctl.sh import <file>          WireGuard, then every VPN plugin installed

set -uo pipefail

# The password file, removed however the script ends
SECRETS=""
trap '[[ -n "$SECRETS" ]] && rm -f "$SECRETS"' EXIT

usage() {
  echo "Usage: $0 {up <uuid> [--password]|import <file>}" >&2
  exit 1
}

up() {
  local uuid="$1" output status
  if [[ "${2:-}" == "--password" ]]; then
    local password
    IFS= read -r password || true
    # nmcli only takes the password from a file: one only you can read, gone right after
    SECRETS="$(umask 077 && mktemp "${XDG_RUNTIME_DIR:-/tmp}/vpnctl.XXXXXX")" || exit 1
    printf 'vpn.secrets.password:%s\n' "$password" >"$SECRETS"
    output="$(nmcli connection up uuid "$uuid" passwd-file "$SECRETS" 2>&1)"
  else
    output="$(nmcli connection up uuid "$uuid" 2>&1)"
  fi
  status=$?
  ((status == 0)) && return 0
  # With no secret agent around, a VPN that asks for a password just fails
  if [[ "$output" == *[Ss]ecrets* ]]; then
    echo "This VPN needs a password" >&2
    exit 3
  fi
  echo "${output##*Error: }" | tail -n 1 >&2
  exit "$status"
}

import() {
  local file="$1" plugin type
  [[ -r "$file" ]] || {
    echo "Can't read $file" >&2
    exit 1
  }
  # nm-connection-editor's way: every importer gets a go until one takes the file
  local types=(wireguard)
  for plugin in /usr/lib/NetworkManager/VPN/*.name; do
    [[ -e "$plugin" ]] || continue
    type="$(sed -n 's/^service=org\.freedesktop\.NetworkManager\.//p' "$plugin")"
    [[ -n "$type" ]] && types+=("$type")
  done
  local output uuid
  for type in "${types[@]}"; do
    output="$(nmcli connection import type "$type" file "$file" 2>/dev/null)" || continue
    # Up only when you ask: a VPN taking all your traffic right at import would surprise
    uuid="$(grep -oE '[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}' <<<"$output" | head -n 1)"
    if [[ -n "$uuid" ]]; then
      nmcli connection modify uuid "$uuid" connection.autoconnect no >/dev/null 2>&1
      nmcli connection down uuid "$uuid" >/dev/null 2>&1
    fi
    return 0
  done
  if ((${#types[@]} == 1)); then
    echo "Not a WireGuard file, and no VPN plugin is installed for other kinds" >&2
  else
    echo "No VPN plugin installed can read this file" >&2
  fi
  exit 1
}

case "${1:-}" in
up)
  [[ -n "${2:-}" ]] || usage
  up "$2" "${3:-}"
  ;;
import)
  [[ -n "${2:-}" ]] || usage
  import "$2"
  ;;
*) usage ;;
esac
