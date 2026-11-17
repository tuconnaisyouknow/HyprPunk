#!/bin/bash
# Puts the keyboard's light out and dims the screen while you're away, and brings both
# back after (see the shell's Idle.qml).
#   idle-lights.sh off keyboard|screen      keeps the light's level aside, then lowers it
#   idle-lights.sh restore keyboard|screen  brings the level kept aside back
#   idle-lights.sh keyboard                 prints the keyboard backlight's device name
# Quietly does nothing for a light the computer doesn't have.

leds_dir="${SYS_LEDS_DIR:-/sys/class/leds}"
# The levels kept aside, each there for as long as its light is lowered. A shell that
# restarts while you're away asks for off twice: the second one would keep the lowered
# level aside and lose yours.
saved_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}/hyprpunk"

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

usage() {
  printf 'Usage: %s {off|restore} {keyboard|screen} | keyboard\n' "$0" >&2
  exit 2
}

# Which light brightnessctl works on, and how low it goes while you're away
case "${2:-$1}" in
keyboard)
  device=$(find_keyboard_backlight) || exit 0
  light=(--device="$device")
  low=0
  ;;
screen)
  light=(--class=backlight)
  low=10
  ;;
*) usage ;;
esac
saved="$saved_dir/idle-light-${2:-$1}"

case "$1" in
off)
  [ -e "$saved" ] && exit 0
  level=$(brightnessctl "${light[@]}" get 2>/dev/null) || exit 0
  mkdir -p "$saved_dir"
  printf '%s\n' "$level" >"$saved"
  brightnessctl "${light[@]}" set "$low" >/dev/null 2>&1
  ;;
restore)
  [ -e "$saved" ] || exit 0
  brightnessctl "${light[@]}" set "$(cat "$saved")" >/dev/null 2>&1
  rm -f "$saved"
  ;;
keyboard)
  printf '%s\n' "$device"
  ;;
*) usage ;;
esac
