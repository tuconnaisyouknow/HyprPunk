#!/bin/bash

power_supply_dir="${SYS_POWER_SUPPLY_DIR:-/sys/class/power_supply}"
backlight_dir="${SYS_BACKLIGHT_DIR:-/sys/class/backlight}"
leds_dir="${SYS_LEDS_DIR:-/sys/class/leds}"
net_dir="${SYS_NET_DIR:-/sys/class/net}"

find_battery() {
  local device type

  for device in "$power_supply_dir"/*; do
    [ -d "$device" ] || continue
    [ -r "$device/type" ] || continue

    type=$(cat "$device/type")
    if [ "$type" = "Battery" ] && [ -r "$device/capacity" ]; then
      printf '%s\n' "$device"
      return 0
    fi
  done

  return 1
}

battery_capacity() {
  local battery

  battery=$(find_battery) || return 1
  cat "$battery/capacity"
}

battery_status() {
  local battery

  battery=$(find_battery) || return 1
  if [ -r "$battery/status" ]; then
    cat "$battery/status"
  else
    printf 'Unknown\n'
  fi
}

backlight_percent() {
  local current max device

  if [ -z "${SYS_BACKLIGHT_DIR:-}" ]; then
    current=$(brightnessctl --class=backlight get 2>/dev/null) || current=
    max=$(brightnessctl --class=backlight max 2>/dev/null) || max=
    if [ -n "$current" ] && [ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null; then
      printf '%d\n' "$((current * 100 / max))"
      return 0
    fi
  fi

  for device in "$backlight_dir"/*; do
    [ -r "$device/brightness" ] || continue
    [ -r "$device/max_brightness" ] || continue

    current=$(cat "$device/brightness")
    max=$(cat "$device/max_brightness")
    if [ "$max" -gt 0 ] 2>/dev/null; then
      printf '%d\n' "$((current * 100 / max))"
      return 0
    fi
  done

  return 1
}

find_keyboard_backlight() {
  local device name max

  for device in "$leds_dir"/*; do
    [ -d "$device" ] || continue
    [ -r "$device/max_brightness" ] || continue

    name=$(basename "$device")
    case "$name" in
      *kbd_backlight*|*keyboard*|*kbd-backlight*)
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

network_type() {
  local active_conn device

  if command -v nmcli >/dev/null 2>&1; then
    active_conn=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | awk -F: '$3 == "connected" && ($2 == "wifi" || $2 == "ethernet") { print $2; exit }')
    case "$active_conn" in
      wifi|ethernet)
        printf '%s\n' "$active_conn"
        return 0
        ;;
    esac
  fi

  for device in "$net_dir"/*; do
    [ -d "$device" ] || continue
    [ "$(basename "$device")" != "lo" ] || continue
    [ -r "$device/operstate" ] || continue
    [ "$(cat "$device/operstate")" = "up" ] || continue

    if [ -d "$device/wireless" ]; then
      printf 'wifi\n'
    else
      printf 'ethernet\n'
    fi
    return 0
  done

  printf 'offline\n'
}
