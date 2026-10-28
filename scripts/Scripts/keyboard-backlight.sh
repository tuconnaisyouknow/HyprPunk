#!/bin/bash
# Turns the keyboard backlight off when idle and back on after (see hypridle.conf).
#   keyboard-backlight.sh off      saves the current level, then switches it off
#   keyboard-backlight.sh restore  brings the saved level back
#   keyboard-backlight.sh status   prints the backlight's device name
# Quietly does nothing on keyboards without a backlight.

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
