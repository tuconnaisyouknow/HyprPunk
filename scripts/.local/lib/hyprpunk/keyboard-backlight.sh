#!/bin/bash
# Turns the keyboard backlight off when idle and back on after (see the shell's Idle.qml).
#   keyboard-backlight.sh off      saves the current level, then switches it off
#   keyboard-backlight.sh restore  brings the saved level back
#   keyboard-backlight.sh status   prints the backlight's device name
# Quietly does nothing on keyboards without a backlight.

leds_dir="${SYS_LEDS_DIR:-/sys/class/leds}"

# Found by its name, which depends on the driver
find_keyboard_backlight() {
  local device name max

  for device in "$leds_dir"/*; do
    [ -r "$device/max_brightness" ] || continue
    name=$(basename "$device")
    case "$name" in
    *kbd_backlight* | *keyboard* | *kbd-backlight*)
      max=$(cat "$device/max_brightness")
      if [ "$max" -gt 0 ] 2>/dev/null; then
        printf '%s\n' "$name"
        return 0
      fi
      ;;
    esac
  done

  return 1
}

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
