#!/usr/bin/env bash
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_FILE="${HYPR_TOUCHPAD_STATE:-$STATE_HOME/hyprpunk/touchpad-state.conf}"
LOCK_FILE="${STATE_FILE}.lock"
DEFAULT_ENABLED=true
TOUCHPADS=""
INPUT_SYSFS="${TOUCHPADCTL_INPUT_SYSFS:-/sys/class/input}"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") ensure
  $(basename "$0") sync
  $(basename "$0") toggle
  $(basename "$0") enable
  $(basename "$0") disable
  $(basename "$0") status
  $(basename "$0") init [true|false]
EOF
}

acquire_lock() {
  if [[ "${TOUCHPADCTL_LOCKED:-false}" == "true" ]]; then
    return 0
  fi
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
  export TOUCHPADCTL_LOCKED=true
}

read_enabled() {
  [[ -f "$STATE_FILE" ]] || return 0
  awk -F= '$1 == "enabled" { print substr($0, length($1) + 2); exit }' "$STATE_FILE"
}

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
    if command -v udevadm >/dev/null 2>&1; then
      local event_path properties hardware_name normalized_name
      for event_path in "$INPUT_SYSFS"/event*; do
        [[ -e "$event_path" ]] || continue
        properties="$(udevadm info -q property -p "$event_path" 2>/dev/null || true)"
        grep -q '^ID_INPUT_TOUCHPAD=1$' <<<"$properties" || continue
        [[ -r "$event_path/device/name" ]] || continue
        hardware_name="$(sed -n '1p' "$event_path/device/name")"
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
  local enabled="$1" dir tmp
  dir="$(dirname "$STATE_FILE")"
  mkdir -p "$dir"
  tmp="$(mktemp --tmpdir="$dir" touchpad-state.XXXXXX)"
  printf 'enabled=%s\n' "$enabled" >"$tmp"
  if [[ -n "$TOUCHPADS" ]]; then
    while IFS= read -r device; do
      [[ -n "$device" ]] && printf 'device=%s\n' "$device"
    done <<<"$TOUCHPADS" >>"$tmp"
  fi
  mv -f "$tmp" "$STATE_FILE"
}

ensure_state() {
  local enabled
  enabled="$(read_enabled || true)"
  if [[ "$enabled" != "true" && "$enabled" != "false" ]]; then
    TOUCHPADS=""
    write_state "$DEFAULT_ENABLED"
  fi
}

reload_hyprland() {
  hyprctl reload >/dev/null 2>&1 || true
}

show_osd() {
  swayosd-client \
    --custom-message "$1" \
    --custom-icon input-touchpad 2>/dev/null || true
}

set_enabled() {
  local enabled="$1"
  load_touchpads
  if [[ -z "$TOUCHPADS" ]]; then
    show_osd "No touchpad detected"
    echo "No touchpad detected." >&2
    return 2
  fi
  write_state "$enabled"
  reload_hyprland
  if [[ "$enabled" == "true" ]]; then
    show_osd "Touchpad On"
  else
    show_osd "Touchpad Off"
  fi
}

command="${1:-}"
case "$command" in
ensure)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  ensure_state
  ;;
sync)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  ensure_state
  enabled="$(read_enabled)"
  previous="$(sed -n '/^device=/p' "$STATE_FILE" 2>/dev/null || true)"
  load_touchpads
  current="$(while IFS= read -r device; do [[ -n "$device" ]] && printf 'device=%s\n' "$device"; done <<<"$TOUCHPADS")"
  if [[ "$previous" != "$current" ]] || grep -q '^synced=' "$STATE_FILE"; then
    write_state "$enabled"
    reload_hyprland
  fi
  ;;
toggle)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  ensure_state
  enabled="$(read_enabled)"
  if [[ "$enabled" == "true" ]]; then
    set_enabled false
  else
    set_enabled true
  fi
  ;;
enable)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  ensure_state
  set_enabled true
  ;;
disable)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  ensure_state
  set_enabled false
  ;;
status)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  enabled="$(read_enabled || true)"
  printf 'enabled=%s\n' "${enabled:-$DEFAULT_ENABLED}"
  [[ -f "$STATE_FILE" ]] && sed -n '/^device=/p' "$STATE_FILE"
  ;;
init)
  [[ $# -le 2 ]] || { usage >&2; exit 1; }
  enabled="${2:-$DEFAULT_ENABLED}"
  [[ "$enabled" == "true" || "$enabled" == "false" ]] || {
    echo "Invalid touchpad state: $enabled" >&2
    exit 1
  }
  acquire_lock
  TOUCHPADS=""
  write_state "$enabled"
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
