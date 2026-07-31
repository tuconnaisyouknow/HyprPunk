#!/usr/bin/env bash
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_FILE="${HYPR_MONITOR_STATE:-$STATE_HOME/hyprpunk/monitor-state.conf}"
LEGACY_STATE_FILE="$HOME/.config/hypr/monitor-state.conf"
LOCK_FILE="${STATE_FILE}.lock"
MONITORS_JSON=""
MONITOR_ID=""
MONITOR_SELECTOR=""
MIGRATED=false

acquire_lock() {
  if [[ "${DISPLAYCTL_LOCKED:-false}" == "true" ]]; then
    return 0
  fi

  if ! command -v flock >/dev/null 2>&1; then
    echo "flock is required to update the monitor state." >&2
    exit 3
  fi

  mkdir -p "$(dirname "$LOCK_FILE")"
  exec 9>"$LOCK_FILE"
  if ! flock -w 10 -x 9; then
    echo "Timed out waiting for the monitor state lock." >&2
    exit 3
  fi
  export DISPLAYCTL_LOCKED=true
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") status
  $(basename "$0") ensure
  $(basename "$0") bootstrap
  $(basename "$0") sync
  $(basename "$0") outputs
  $(basename "$0") modes <output>
  $(basename "$0") resolutions <output>
  $(basename "$0") frequencies <output>
  $(basename "$0") resolution <output> <WIDTHxHEIGHT>
  $(basename "$0") mode <output> <resolution[@refresh]>
  $(basename "$0") refresh <output> <frequency>
  $(basename "$0") scale <output> <auto|factor>
  $(basename "$0") position <output> <left|right|above|below> <reference>
  $(basename "$0") reflow
  $(basename "$0") auto-layout
  $(basename "$0") auto <output>
  $(basename "$0") reset
  $(basename "$0") init [preferred|WIDTHxHEIGHT]
EOF
}

read_value() {
  local key="$1"
  [[ -f "$STATE_FILE" ]] || return 0
  awk -F= -v key="$key" '$1 == key { print substr($0, length($1) + 2); exit }' "$STATE_FILE"
}

write_value() {
  local key="$1" value="$2" dir tmp
  dir="$(dirname "$STATE_FILE")"
  mkdir -p "$dir"
  tmp="$(mktemp --tmpdir="$dir" monitor-state.XXXXXX)"

  if [[ -f "$STATE_FILE" ]]; then
    awk -F= -v key="$key" '$1 != key' "$STATE_FILE" >"$tmp"
  fi
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

delete_value() {
  local key="$1" dir tmp
  [[ -f "$STATE_FILE" ]] || return 0
  dir="$(dirname "$STATE_FILE")"
  tmp="$(mktemp --tmpdir="$dir" monitor-state.XXXXXX)"
  awk -F= -v key="$key" '$1 != key' "$STATE_FILE" >"$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

delete_matching_values() {
  local pattern="$1" dir tmp
  [[ -f "$STATE_FILE" ]] || return 0
  dir="$(dirname "$STATE_FILE")"
  tmp="$(mktemp --tmpdir="$dir" monitor-state.XXXXXX)"
  awk -F= -v pattern="$pattern" '$1 !~ pattern' "$STATE_FILE" >"$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

remove_legacy_state() {
  local dir tmp
  [[ -f "$STATE_FILE" ]] || return 0
  dir="$(dirname "$STATE_FILE")"
  tmp="$(mktemp --tmpdir="$dir" monitor-state.XXXXXX)"
  awk -F= '$1 != "profile" && $1 != "refresh_optimized"' "$STATE_FILE" >"$tmp"
  if cmp -s "$STATE_FILE" "$tmp"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$STATE_FILE"
  fi
}

migrate_state_file() {
  [[ -z "${HYPR_MONITOR_STATE:-}" ]] || return 0
  [[ ! -f "$STATE_FILE" && -f "$LEGACY_STATE_FILE" ]] || return 0
  mkdir -p "$(dirname "$STATE_FILE")"
  mv "$LEGACY_STATE_FILE" "$STATE_FILE"
}

reload_hyprland() {
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
}

load_monitors() {
  if ! command -v hyprctl >/dev/null 2>&1; then
    echo "No running Hyprland session." >&2
    exit 2
  fi
  MONITORS_JSON="$(hyprctl monitors all -j)" || {
    echo "No running Hyprland session." >&2
    exit 2
  }
  jq empty <<<"$MONITORS_JSON" || {
    echo "Invalid monitor data returned by Hyprland." >&2
    exit 2
  }
}

set_monitor_identity() {
  local output="$1" make="$2" model="$3" serial="$4" description="$5"
  local identity duplicate_count

  if [[ -n "$serial" ]]; then
    identity="$make|$model|$serial"
    MONITOR_SELECTOR="desc:$description"
  else
    duplicate_count="$(
      jq -r --arg description "$description" \
        '[.[] | select(.description == $description)] | length' <<<"$MONITORS_JSON"
    )"
    if [[ "$duplicate_count" -gt 1 ]]; then
      # Identical displays without serial numbers cannot be distinguished by
      # EDID. Keep them separate using their current connectors.
      identity="$description|$output"
      MONITOR_SELECTOR="$output"
    else
      identity="$description"
      MONITOR_SELECTOR="desc:$description"
    fi
  fi

  MONITOR_ID="$(
    printf '%s' "$identity" |
      sha256sum |
      cut -c1-16
  )"
}

resolve_monitor() {
  local output="$1" fields
  fields="$(
    jq -er --arg output "$output" '
      .[] |
      select(.name == $output and .disabled != true) |
      [.name, (.make // ""), (.model // ""), (.serial // ""), .description] |
      join("\u001f")
    ' <<<"$MONITORS_JSON"
  )" || {
    echo "Unknown output: $output" >&2
    exit 1
  }
  IFS=$'\x1f' read -r output make model serial description <<<"$fields"
  set_monitor_identity "$output" "$make" "$model" "$serial" "$description"
}

supported_mode() {
  local output="$1" requested="${2%Hz}"
  local resolution frequency

  if [[ "$requested" == *@* ]]; then
    resolution="${requested%%@*}"
    frequency="${requested#*@}"
    jq -er \
      --arg output "$output" \
      --arg resolution "$resolution" \
      --argjson frequency "$frequency" '
        [
          .[] |
          select(.name == $output and .disabled != true) |
          .availableModes[] |
          select(startswith($resolution + "@")) |
          . as $mode |
          (
            sub("^.*@"; "") |
            sub("Hz$"; "") |
            tonumber
          ) as $advertised_frequency |
          select(($advertised_frequency - $frequency | fabs) < 0.001) |
          $mode |
          sub("Hz$"; "")
        ][0] // empty
      ' <<<"$MONITORS_JSON"
  else
    jq -er \
      --arg output "$output" \
      --arg resolution "$requested" '
        [
          .[] |
          select(.name == $output and .disabled != true) |
          .availableModes[] |
          select(startswith($resolution + "@")) |
          $resolution
        ][0] // empty
      ' <<<"$MONITORS_JSON"
  fi
}

migrate_monitor_state() {
  local output="$1" id="$2" selector="$3"
  local legacy_mode legacy_scale legacy_position current_selector
  legacy_mode="$(read_value "mode.$output" || true)"
  legacy_scale="$(read_value "scale.$output" || true)"
  legacy_position="$(read_value "position.$output" || true)"
  current_selector="$(read_value "selector.$id" || true)"
  MIGRATED=false

  if [[ "$current_selector" != "$selector" ]]; then
    write_value "selector.$id" "$selector"
    MIGRATED=true
  fi
  if [[ -n "$legacy_mode" && -z "$(read_value "mode.$id" || true)" ]]; then
    write_value "mode.$id" "$legacy_mode"
    MIGRATED=true
  fi
  if [[ -n "$legacy_position" && -z "$(read_value "position.$id" || true)" ]]; then
    write_value "position.$id" "$legacy_position"
    MIGRATED=true
  fi
  if [[ -n "$legacy_scale" && -z "$(read_value "scale.$id" || true)" ]]; then
    write_value "scale.$id" "$legacy_scale"
    MIGRATED=true
  fi

  if [[ -n "$legacy_mode" ]]; then
    delete_value "mode.$output"
    MIGRATED=true
  fi
  if [[ -n "$legacy_position" ]]; then
    delete_value "position.$output"
    MIGRATED=true
  fi
  if [[ -n "$legacy_scale" ]]; then
    delete_value "scale.$output"
    MIGRATED=true
  fi
}

active_output_for_id() {
  local wanted_id="$1"
  local fields output make model serial description

  while IFS=$'\x1f' read -r output make model serial description; do
    set_monitor_identity "$output" "$make" "$model" "$serial" "$description"
    if [[ "$MONITOR_ID" == "$wanted_id" ]]; then
      printf '%s\n' "$output"
      return 0
    fi
  done < <(
    jq -r '
      .[] |
      select(.disabled != true) |
      [.name, (.make // ""), (.model // ""), (.serial // ""), .description] |
      join("\u001f")
    ' <<<"$MONITORS_JSON"
  )
  return 1
}

would_create_layout_cycle() {
  local moved_id="$1" current_id="$2"
  local relation next_id seen=" "

  while [[ -n "$current_id" ]]; do
    if [[ "$current_id" == "$moved_id" ]]; then
      return 0
    fi
    if [[ "$seen" == *" $current_id "* ]]; then
      # The referenced chain is already cyclic. Do not attach another output
      # to invalid layout state.
      return 0
    fi
    seen+="$current_id "

    relation="$(read_value "relative.$current_id" || true)"
    [[ "$relation" == *:* ]] || break
    next_id="${relation#*:}"
    [[ -n "$next_id" && "$next_id" != "$relation" ]] || break
    current_id="$next_id"
  done

  return 1
}

reflow_layout() {
  local fields output make model serial description x y logical_width logical_height
  local moved_id updates="" min_x min_y normalized_x normalized_y
  declare -A active pos_x pos_y width height resolved visiting

  nearest_active_reference() {
    local current_id="$1" relation next_id
    declare -A seen_reference

    while [[ -n "$current_id" && -z "${seen_reference[$current_id]:-}" ]]; do
      if [[ -n "${active[$current_id]:-}" ]]; then
        printf '%s\n' "$current_id"
        return 0
      fi
      seen_reference["$current_id"]=true
      relation="$(read_value "relative.$current_id" || true)"
      [[ "$relation" == *:* ]] || return 1
      next_id="${relation#*:}"
      [[ -n "$next_id" && "$next_id" != "$relation" ]] || return 1
      current_id="$next_id"
    done

    return 1
  }

  resolve_layout_position() {
    local id="$1" relation direction reference_id saved_position

    [[ -n "${active[$id]:-}" ]] || return 1
    [[ -z "${resolved[$id]:-}" ]] || return 0
    [[ -z "${visiting[$id]:-}" ]] || return 1
    visiting["$id"]=true

    relation="$(read_value "relative.$id" || true)"
    if [[ "$relation" == *:* ]]; then
      direction="${relation%%:*}"
      reference_id="$(nearest_active_reference "${relation#*:}" || true)"
      if [[ -n "$reference_id" &&
        "$direction" =~ ^(left|right|above|below)$ ]] &&
        resolve_layout_position "$reference_id"; then
        case "$direction" in
        left)
          pos_x["$id"]=$((pos_x[$reference_id] - width[$id]))
          pos_y["$id"]="${pos_y[$reference_id]}"
          ;;
        right)
          pos_x["$id"]=$((pos_x[$reference_id] + width[$reference_id]))
          pos_y["$id"]="${pos_y[$reference_id]}"
          ;;
        above)
          pos_x["$id"]="${pos_x[$reference_id]}"
          pos_y["$id"]=$((pos_y[$reference_id] - height[$id]))
          ;;
        below)
          pos_x["$id"]="${pos_x[$reference_id]}"
          pos_y["$id"]=$((pos_y[$reference_id] + height[$reference_id]))
          ;;
        esac
      else
        # No ancestor from this relation is currently connected. Treat this
        # output as the temporary root of the remaining active sub-layout.
        saved_position="$(read_value "position.$id" || true)"
        if [[ "$saved_position" =~ ^-?[0-9]+x-?[0-9]+$ ]]; then
          pos_x["$id"]="${saved_position%%x*}"
          pos_y["$id"]="${saved_position#*x}"
        fi
      fi
    else
      saved_position="$(read_value "position.$id" || true)"
      if [[ "$saved_position" =~ ^-?[0-9]+x-?[0-9]+$ ]]; then
        pos_x["$id"]="${saved_position%%x*}"
        pos_y["$id"]="${saved_position#*x}"
      fi
    fi

    unset 'visiting[$id]'
    resolved["$id"]=true
    return 0
  }

  [[ "$(read_value layout || true)" == "custom" ]] || return 0
  load_monitors

  while IFS=$'\x1f' read -r output make model serial description x y logical_width logical_height; do
    set_monitor_identity "$output" "$make" "$model" "$serial" "$description"
    active["$MONITOR_ID"]=true
    pos_x["$MONITOR_ID"]="$x"
    pos_y["$MONITOR_ID"]="$y"
    width["$MONITOR_ID"]="$logical_width"
    height["$MONITOR_ID"]="$logical_height"
  done < <(
    jq -r '
      .[] |
      select(.disabled != true) |
      [
        .name,
        (.make // ""),
        (.model // ""),
        (.serial // ""),
        .description,
        (.x | tostring),
        (.y | tostring),
        ((.width / .scale | floor) | tostring),
        ((.height / .scale | floor) | tostring)
      ] |
      join("\u001f")
    ' <<<"$MONITORS_JSON"
  )

  [[ ${#active[@]} -gt 0 ]] || return 0
  for moved_id in "${!active[@]}"; do
    resolve_layout_position "$moved_id" || continue
    if [[ -z "${min_x+x}" || pos_x[$moved_id] -lt min_x ]]; then
      min_x="${pos_x[$moved_id]}"
    fi
    if [[ -z "${min_y+x}" || pos_y[$moved_id] -lt min_y ]]; then
      min_y="${pos_y[$moved_id]}"
    fi
  done

  # Translation does not alter the relative layout. Keeping the active bounds
  # at the origin removes empty space left by a disconnected root monitor.
  for moved_id in "${!resolved[@]}"; do
    normalized_x=$((pos_x[$moved_id] - min_x))
    normalized_y=$((pos_y[$moved_id] - min_y))
    updates+="${moved_id}=${normalized_x}x${normalized_y}"$'\n'
  done

  [[ -n "$updates" ]] || return 0
  local dir tmp
  dir="$(dirname "$STATE_FILE")"
  tmp="$(mktemp --tmpdir="$dir" monitor-state.XXXXXX)"
  awk -F= -v updates="$updates" '
    BEGIN {
      count = split(updates, lines, "\n")
      for (i = 1; i <= count; i++) {
        if (lines[i] == "") continue
        separator = index(lines[i], "=")
        id = substr(lines[i], 1, separator - 1)
        values["position." id] = substr(lines[i], separator + 1)
      }
    }
    {
      if ($1 in values) {
        print $1 "=" values[$1]
        written[$1] = 1
      } else {
        print
      }
    }
    END {
      for (key in values) {
        if (!(key in written)) print key "=" values[key]
      }
    }
  ' "$STATE_FILE" >"$tmp"
  mv -f "$tmp" "$STATE_FILE"
  reload_hyprland
}

command="${1:-}"
case "$command" in
ensure)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  migrate_state_file
  if [[ ! -f "$STATE_FILE" ]]; then
    "$0" init preferred
  fi
  remove_legacy_state
  if [[ -z "$(read_value default_scale || true)" ]]; then
    write_value default_scale auto
  fi
  ;;
bootstrap)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  "$0" ensure
  "$0" sync
  ;;
sync | optimize)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  load_monitors
  changed=false
  if [[ -z "$(read_value default_scale || true)" ]]; then
    write_value default_scale auto
    changed=true
  fi
  while IFS=$'\x1f' read -r output make model serial description best_mode; do
    [[ -n "$output" && -n "$best_mode" ]] || continue
    set_monitor_identity "$output" "$make" "$model" "$serial" "$description"
    migrate_monitor_state "$output" "$MONITOR_ID" "$MONITOR_SELECTOR"
    [[ "$MIGRATED" == "false" ]] || changed=true
    if [[ -z "$(read_value "scale.$MONITOR_ID" || true)" ]]; then
      write_value "scale.$MONITOR_ID" "auto"
      changed=true
    fi
    [[ -n "$(read_value "mode.$MONITOR_ID" || true)" ]] && continue
    write_value "mode.$MONITOR_ID" "${best_mode%Hz}"
    changed=true
  done < <(jq -r '
        .[] |
        select(.disabled != true) |
        . as $output |
        ((.width | tostring) + "x" + (.height | tostring)) as $resolution |
        [
          .availableModes[] |
          select(startswith($resolution + "@")) |
          {
            mode: .,
            refresh: (
              sub("^.*@"; "") |
              sub("Hz$"; "") |
              tonumber
            )
          }
        ] |
        sort_by(.refresh) |
        last |
        select(. != null) |
        [
          $output.name,
          ($output.make // ""),
          ($output.model // ""),
          ($output.serial // ""),
          $output.description,
          .mode
        ] |
        join("\u001f")
      ' <<<"$MONITORS_JSON")
  [[ "$changed" == "false" ]] || reload_hyprland
  if [[ "${DISPLAYCTL_REFLOWING:-false}" != "true" ]]; then
    reflow_layout
  fi
  ;;
status)
  current_default="$(read_value default_mode || true)"
  current_scale="$(read_value default_scale || true)"
  current_layout="$(read_value layout || true)"
  printf 'layout=%s\n' "${current_layout:-auto}"
  printf 'default_mode=%s\n' "${current_default:-preferred}"
  printf 'default_scale=%s\n' "${current_scale:-auto}"
  [[ -f "$STATE_FILE" ]] &&
    awk -F= '$1 ~ /^(selector|mode|scale|position|relative)\./ { print }' "$STATE_FILE"
  ;;
outputs)
  load_monitors
  jq -r '.[] | select(.disabled != true) | .name' <<<"$MONITORS_JSON"
  ;;
modes)
  [[ $# -eq 2 ]] || { usage >&2; exit 1; }
  load_monitors
  jq -r --arg output "$2" \
    '.[] | select(.name == $output) | .availableModes[]' <<<"$MONITORS_JSON"
  ;;
resolutions)
  [[ $# -eq 2 ]] || { usage >&2; exit 1; }
  load_monitors
  jq -r --arg output "$2" '
      [
        .[] |
        select(.name == $output and .disabled != true) |
        .availableModes[] |
        sub("@.*$"; "")
      ] |
      unique[]
    ' <<<"$MONITORS_JSON"
  ;;
frequencies)
  [[ $# -eq 2 ]] || { usage >&2; exit 1; }
  load_monitors
  jq -r --arg output "$2" '
      .[] |
      select(.name == $output) |
      (.width | tostring) + "x" + (.height | tostring) as $resolution |
      .availableModes[] |
      select(startswith($resolution + "@")) |
      sub("^.*@"; "") |
      sub("Hz$"; "")
    ' <<<"$MONITORS_JSON" | awk '!seen[$0]++'
  ;;
resolution)
  [[ $# -eq 3 ]] || { usage >&2; exit 1; }
  [[ "$2" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Invalid output: $2" >&2; exit 1; }
  [[ "$3" =~ ^[0-9]+x[0-9]+$ ]] ||
    { echo "Invalid resolution: $3" >&2; exit 1; }
  acquire_lock
  load_monitors
  resolve_monitor "$2"
  selected_mode="$(
    jq -er \
      --arg output "$2" \
      --arg resolution "$3" '
        .[] |
        select(.name == $output and .disabled != true) |
        . as $output |
        [
          .availableModes[] |
          select(startswith($resolution + "@")) |
          {
            mode: sub("Hz$"; ""),
            frequency: (
              sub("^.*@"; "") |
              sub("Hz$"; "") |
              tonumber
            )
          }
        ] as $modes |
        (
          ($modes | map(select((.frequency - $output.refreshRate | fabs) < 0.01)) | first) //
          ($modes | sort_by(.frequency) | last)
        ) |
        select(. != null) |
        .mode
      ' <<<"$MONITORS_JSON"
  )" || {
    echo "Unsupported resolution for $2: $3" >&2
    exit 1
  }
  migrate_monitor_state "$2" "$MONITOR_ID" "$MONITOR_SELECTOR"
  write_value "mode.$MONITOR_ID" "$selected_mode"
  reload_hyprland
  if [[ "${DISPLAYCTL_REFLOWING:-false}" != "true" ]]; then
    reflow_layout
  fi
  ;;
mode)
  [[ $# -eq 3 ]] || { usage >&2; exit 1; }
  [[ "$2" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Invalid output: $2" >&2; exit 1; }
  [[ "$3" =~ ^[0-9]+x[0-9]+(@[0-9.]+)?(Hz)?$ ]] ||
    { echo "Invalid mode: $3" >&2; exit 1; }
  acquire_lock
  load_monitors
  resolve_monitor "$2"
  canonical_mode="$(supported_mode "$2" "$3" || true)"
  [[ -n "$canonical_mode" ]] ||
    { echo "Unsupported mode for $2: $3" >&2; exit 1; }
  migrate_monitor_state "$2" "$MONITOR_ID" "$MONITOR_SELECTOR"
  write_value "mode.$MONITOR_ID" "$canonical_mode"
  reload_hyprland
  if [[ "${DISPLAYCTL_REFLOWING:-false}" != "true" ]]; then
    reflow_layout
  fi
  ;;
refresh)
  [[ $# -eq 3 ]] || { usage >&2; exit 1; }
  [[ "$2" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Invalid output: $2" >&2; exit 1; }
  [[ "$3" =~ ^[0-9]+([.][0-9]+)?(Hz)?$ ]] ||
    { echo "Invalid frequency: $3" >&2; exit 1; }
  acquire_lock
  load_monitors
  resolution="$(
    jq -r --arg output "$2" '
        .[] | select(.name == $output) |
        (.width | tostring) + "x" + (.height | tostring)
      ' <<<"$MONITORS_JSON"
  )"
  [[ -n "$resolution" ]] || { echo "Unknown output: $2" >&2; exit 1; }
  frequency="${3%Hz}"
  "$0" mode "$2" "$resolution@$frequency"
  ;;
scale)
  [[ $# -eq 3 ]] || { usage >&2; exit 1; }
  [[ "$2" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Invalid output: $2" >&2; exit 1; }
  [[ "$3" == "auto" || "$3" =~ ^(1|1[.]25|1[.]5|1[.]75|2)$ ]] ||
    { echo "Invalid scale: $3" >&2; exit 1; }
  acquire_lock
  load_monitors
  resolve_monitor "$2"
  migrate_monitor_state "$2" "$MONITOR_ID" "$MONITOR_SELECTOR"
  write_value "scale.$MONITOR_ID" "$3"
  reload_hyprland
  if [[ "${DISPLAYCTL_REFLOWING:-false}" != "true" ]]; then
    reflow_layout
  fi
  ;;
position)
  [[ $# -eq 4 ]] || { usage >&2; exit 1; }
  output="$2"
  direction="$3"
  reference="$4"
  [[ "$output" =~ ^[A-Za-z0-9._-]+$ && "$reference" =~ ^[A-Za-z0-9._-]+$ ]] ||
    { echo "Invalid output name." >&2; exit 1; }
  [[ "$output" != "$reference" ]] || { echo "An output cannot reference itself." >&2; exit 1; }
  [[ "$direction" =~ ^(left|right|above|below)$ ]] ||
    { echo "Invalid direction: $direction" >&2; exit 1; }
  acquire_lock
  load_monitors
  resolve_monitor "$output"
  output_id="$MONITOR_ID"
  output_selector="$MONITOR_SELECTOR"
  resolve_monitor "$reference"
  reference_id="$MONITOR_ID"
  reference_selector="$MONITOR_SELECTOR"
  [[ "$output_id" != "$reference_id" ]] ||
    { echo "The selected outputs have the same monitor identity." >&2; exit 1; }
  if would_create_layout_cycle "$output_id" "$reference_id"; then
    echo "Unable to position $output relative to $reference: this would create a layout cycle." >&2
    exit 1
  fi

  coordinates="$(
    jq -er \
        --arg output "$output" \
        --arg reference "$reference" \
        --arg direction "$direction" '
        (.[] | select(.name == $output and .disabled != true)) as $moved |
        (.[] | select(.name == $reference and .disabled != true)) as $ref |
        ($moved.width / $moved.scale | floor) as $mw |
        ($moved.height / $moved.scale | floor) as $mh |
        ($ref.width / $ref.scale | floor) as $rw |
        ($ref.height / $ref.scale | floor) as $rh |
        if $direction == "left" then
          (($ref.x - $mw) | tostring) + "x" + ($ref.y | tostring)
        elif $direction == "right" then
          (($ref.x + $rw) | tostring) + "x" + ($ref.y | tostring)
        elif $direction == "above" then
          ($ref.x | tostring) + "x" + (($ref.y - $mh) | tostring)
        else
          ($ref.x | tostring) + "x" + (($ref.y + $rh) | tostring)
        end
      ' <<<"$MONITORS_JSON"
  )" || { echo "Unable to calculate output position." >&2; exit 2; }

  # Preserve the reference at its current coordinates, then place the selected
  # output next to it. This makes the result stable after a reload.
  reference_position="$(
    jq -er --arg reference "$reference" '
        .[] | select(.name == $reference and .disabled != true) |
        (.x | tostring) + "x" + (.y | tostring)
      ' <<<"$MONITORS_JSON"
  )"
  migrate_monitor_state "$output" "$output_id" "$output_selector"
  migrate_monitor_state "$reference" "$reference_id" "$reference_selector"
  reference_mode="$(read_value "mode.$reference_id" || true)"
  output_mode="$(read_value "mode.$output_id" || true)"
  write_value layout custom
  write_value "position.$reference_id" "$reference_position"
  write_value "position.$output_id" "$coordinates"
  write_value "relative.$output_id" "$direction:$reference_id"
  write_value "mode.$reference_id" "${reference_mode:-preferred}"
  write_value "mode.$output_id" "${output_mode:-preferred}"
  if [[ "${DISPLAYCTL_REFLOWING:-false}" != "true" ]]; then
    reflow_layout
  else
    reload_hyprland
  fi
  ;;
reflow)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  reflow_layout
  ;;
auto-layout)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  write_value layout auto
  delete_matching_values '^(position|relative)[.]'
  reload_hyprland
  ;;
auto)
  [[ $# -eq 2 ]] || { usage >&2; exit 1; }
  [[ "$2" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Invalid output: $2" >&2; exit 1; }
  acquire_lock
  load_monitors
  resolve_monitor "$2"
  migrate_monitor_state "$2" "$MONITOR_ID" "$MONITOR_SELECTOR"
  write_value "mode.$MONITOR_ID" "preferred"
  reload_hyprland
  if [[ "${DISPLAYCTL_REFLOWING:-false}" != "true" ]]; then
    reflow_layout
  fi
  ;;
reset)
  [[ $# -eq 1 ]] || { usage >&2; exit 1; }
  acquire_lock
  "$0" init preferred
  if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors all -j >/dev/null 2>&1; then
    "$0" sync
  else
    echo "Defaults saved; outputs will be detected when Hyprland starts."
  fi
  ;;
init)
  [[ $# -le 2 ]] || { usage >&2; exit 1; }
  initial_mode="${2:-preferred}"
  [[ "$initial_mode" == "preferred" || "$initial_mode" =~ ^[0-9]+x[0-9]+$ ]] ||
    { echo "Invalid initial mode: $initial_mode" >&2; exit 1; }
  acquire_lock
  state_dir="$(dirname "$STATE_FILE")"
  mkdir -p "$state_dir"
  state_tmp="$(mktemp --tmpdir="$state_dir" monitor-state.XXXXXX)"
  printf 'layout=auto\ndefault_mode=%s\ndefault_scale=auto\n' "$initial_mode" >"$state_tmp"
  mv -f "$state_tmp" "$STATE_FILE"
  echo "Monitor configuration initialized with mode: $initial_mode"
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
