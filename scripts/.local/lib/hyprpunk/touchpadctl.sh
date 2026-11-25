#!/usr/bin/env bash
# Turns the touchpad on and off, and remembers it. Hyprland applies the saved state
# through input.lua, and the shell's bar shows it. No file means on.
#   touchpadctl.sh toggle | enable | disable   from the touchpad key or the shell
#   touchpadctl.sh sync                        at login: finds the touchpads again
#   touchpadctl.sh status
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_FILE="${HYPR_TOUCHPAD_STATE:-$STATE_HOME/hyprpunk/touchpad-state.conf}"
LOCK_FILE="${STATE_FILE}.lock"
TOUCHPADS=""
INPUT_SYSFS="${TOUCHPADCTL_INPUT_SYSFS:-/sys/class/input}"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") sync
  $(basename "$0") toggle
  $(basename "$0") enable
  $(basename "$0") disable
  $(basename "$0") status
EOF
}

# One change at a time, a key held down sends a few in a row
acquire_lock() {
  command -v flock >/dev/null 2>&1 || {
    echo "flock is required to update the touchpad state." >&2
    exit 3
  }
  mkdir -p "$(dirname "$STATE_FILE")"
  exec 9>"$LOCK_FILE"
  flock -w 10 -x 9 || {
    echo "Timed out waiting for the touchpad state lock." >&2
    exit 3
  }
}

# On unless saved off
read_enabled() {
  if [[ -f "$STATE_FILE" ]] && grep -qx 'enabled=false' "$STATE_FILE"; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

# The device lines, as the state file keeps them
device_lines() {
  local device
  while IFS= read -r device; do
    [[ -z "$device" ]] || printf 'device=%s\n' "$device"
  done <<<"$TOUCHPADS"
}

# Hyprland's pointer devices that are touchpads: those udev flags as one (under the
# name Hyprland gives them), plus anything called touchpad or trackpad
load_touchpads() {
  local devices_json udev_touchpads_json
  command -v hyprctl >/dev/null 2>&1 || {
    echo "hyprctl is required to detect touchpads." >&2
    return 2
  }
  devices_json="$(hyprctl devices -j)" || {
    echo "No running Hyprland session." >&2
    return 2
  }
  jq -e 'type == "object"' <<<"$devices_json" >/dev/null 2>&1 || {
    echo "Invalid device data returned by Hyprland." >&2
    return 2
  }
  udev_touchpads_json="$(
    # One udevadm for every device, so the touchpad key answers at once
    if command -v udevadm >/dev/null 2>&1 && compgen -G "$INPUT_SYSFS/event*" >/dev/null; then
      local event hardware_name normalized_name
      udevadm info -q property "$INPUT_SYSFS"/event* 2>/dev/null |
        awk -F= '$1 == "DEVPATH" { n = split($2, parts, "/"); event = parts[n] }
                 $0 == "ID_INPUT_TOUCHPAD=1" { print event }' |
        while IFS= read -r event; do
          [[ -r "$INPUT_SYSFS/$event/device/name" ]] || continue
          hardware_name="$(sed -n '1p' "$INPUT_SYSFS/$event/device/name")"
          normalized_name="$(
            printf '%s' "$hardware_name" |
              LC_ALL=C tr '[:upper:]' '[:lower:]' |
              sed -E 's/[^a-z0-9:_-]+/-/g; s/^-+//; s/-+$//'
          )"
          [[ -n "$normalized_name" ]] && printf '%s\n' "$normalized_name"
        done
    fi |
      jq -Rsc 'split("\n") | map(select(length > 0)) | unique'
  )"
  TOUCHPADS="$(
    jq -er --argjson udev_touchpads "$udev_touchpads_json" '
      [
        .mice[]? |
        .name // empty |
        . as $name |
        select(
          ($udev_touchpads | index($name)) != null or
          ($name | test("(touchpad|trackpad)"; "i"))
        )
      ] |
      unique[]
    ' <<<"$devices_json" 2>/dev/null || true
  )"
}

write_state() {
  local dir tmp
  dir="$(dirname "$STATE_FILE")"
  mkdir -p "$dir"
  tmp="$(mktemp --tmpdir="$dir" touchpad-state.XXXXXX)"
  {
    printf 'enabled=%s\n' "$1"
    device_lines
  } >"$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

# On and off show up in the shell's bar, which watches the state file; only errors notify
set_enabled() {
  load_touchpads
  if [[ -z "$TOUCHPADS" ]]; then
    notify-send -a Touchpad -i input-touchpad "No touchpad detected" 2>/dev/null || true
    echo "No touchpad detected." >&2
    exit 2
  fi
  write_state "$1"
  hyprctl reload >/dev/null 2>&1 || true
}

command="${1:-}"
[[ $# -eq 1 ]] || command=""
case "$command" in
# Written again only when the touchpads changed
sync)
  acquire_lock
  load_touchpads
  if [[ "$(sed -n '/^device=/p' "$STATE_FILE" 2>/dev/null || true)" != "$(device_lines)" ]]; then
    write_state "$(read_enabled)"
    hyprctl reload >/dev/null 2>&1 || true
  fi
  ;;
toggle)
  acquire_lock
  if [[ "$(read_enabled)" == "true" ]]; then
    set_enabled false
  else
    set_enabled true
  fi
  ;;
enable)
  acquire_lock
  set_enabled true
  ;;
disable)
  acquire_lock
  set_enabled false
  ;;
status)
  printf 'enabled=%s\n' "$(read_enabled)"
  [[ ! -f "$STATE_FILE" ]] || sed -n '/^device=/p' "$STATE_FILE"
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
