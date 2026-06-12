#!/bin/bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/system-info.sh
source "$script_dir/lib/system-info.sh"

device=$(find_keyboard_backlight) || exit 0

case "${1:-}" in
  off)
    brightnessctl --device="$device" -s set 0 >/dev/null 2>&1
    ;;
  restore)
    brightnessctl --device="$device" -r >/dev/null 2>&1
    ;;
  status)
    printf '%s\n' "$device"
    ;;
  *)
    printf 'Usage: %s {off|restore|status}\n' "$0" >&2
    exit 2
    ;;
esac
