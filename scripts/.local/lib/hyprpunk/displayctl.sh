#!/usr/bin/env bash
# Remembers how each screen is set up, and finds it again whichever port it's plugged into.
#
# Every screen gets an ID from its EDID (make, model, serial), and under that ID:
#   selector          how Hyprland finds it (its description, or its port)
#   mode, scale       resolution, refresh rate and scaling
#   slot              its number, 1 to 10, shown in the shell
#   workspaces        the workspaces it holds (its own number by default)
#   relative          where it sits next to another screen, in a custom layout
#   position          where that puts it, worked out from the relations
# All of it in ~/.local/state/hyprpunk/monitor-state.conf, which monitors.lua and
# workspaces.lua read. No file means Hyprland's automatic setup for every screen.
#
#   displayctl.sh sync                         at login and when a screen is plugged in
#   displayctl.sh reflow                       when one goes away (autostart.lua)
#   displayctl.sh info | status                the screens, as JSON for the shell or to read
#   displayctl.sh mode <port> <preferred|WIDTHxHEIGHT[@rate]>
#   displayctl.sh scale <port> <auto|1|1.25|1.5|1.75|2>
#   displayctl.sh slot <port> <1-10>
#   displayctl.sh workspaces <port> <list|none>
#   displayctl.sh position <port> <left|right|above|below> <port>
#   displayctl.sh auto-layout | reset          lines them up again, or forgets everything
#   displayctl.sh try <command…> | undo        a change you can take back (the settings)
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_FILE="${HYPR_MONITOR_STATE:-$STATE_HOME/hyprpunk/monitor-state.conf}"
BACKUP_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/hyprpunk/monitor-state.backup"
LOCK_FILE="${STATE_FILE}.lock"
MONITORS_JSON=""
MONITOR_ID=""
MONITOR_SELECTOR=""

# A screen's size once scaled and turned, as the layout sees it
LOGICAL_SIZE='def logical_size: .scale as $scale | (if .transform % 2 == 1 then [.height, .width] else [.width, .height] end) | map(. / $scale);'

usage() {
  cat <<EOF
Usage:
  $(basename "$0") sync
  $(basename "$0") reflow
  $(basename "$0") info
  $(basename "$0") status
  $(basename "$0") mode <port> <preferred|WIDTHxHEIGHT[@rate]>
  $(basename "$0") scale <port> <auto|1|1.25|1.5|1.75|2>
  $(basename "$0") slot <port> <1-10>
  $(basename "$0") workspaces <port> <list|none>
  $(basename "$0") position <port> <left|right|above|below> <port>
  $(basename "$0") auto-layout
  $(basename "$0") reset
  $(basename "$0") try <command…>
  $(basename "$0") undo
EOF
}

fail() {
  echo "$*" >&2
  exit 1
}

# Every command takes a set number of arguments, its name included
expect() {
  local count="$1"
  shift
  [[ $# -eq $count ]] || {
    usage >&2
    exit 1
  }
}

# One change at a time: plugging two screens fires two syncs at once
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

#########
# STATE #
#########

# Plain key=value lines. Read as empty while there's no file yet.
state() {
  if [[ -f "$STATE_FILE" ]]; then
    printf '%s\n' "$STATE_FILE"
  else
    printf '/dev/null\n'
  fi
}

read_value() {
  awk -F= -v key="$1" '$1 == key { print substr($0, length($1) + 2); exit }' "$(state)"
}

# Every change runs the whole file through awk, then swaps it in at once, so Hyprland
# never reads half of one
rewrite_state() {
  local dir tmp
  dir="$(dirname "$STATE_FILE")"
  mkdir -p "$dir"
  tmp="$(mktemp --tmpdir="$dir" monitor-state.XXXXXX)"
  awk -F= "$@" "$(state)" >"$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

# Each key=value given replaces its line where it is, or comes at the end
write_values() {
  local IFS=$'\n'
  rewrite_state -v updates="$*" '
    BEGIN {
      count = split(updates, lines, "\n")
      for (i = 1; i <= count; i++) {
        at = index(lines[i], "=")
        order[i] = substr(lines[i], 1, at - 1)
        values[order[i]] = substr(lines[i], at + 1)
      }
    }
    $1 in values {
      if (!($1 in written)) print $1 "=" values[$1]
      written[$1] = 1
      next
    }
    { print }
    END {
      for (i = 1; i <= count; i++) {
        if (!(order[i] in written)) print order[i] "=" values[order[i]]
        written[order[i]] = 1
      }
    }
  '
}

delete_values() {
  rewrite_state -v pattern="$1" '$1 !~ pattern'
}

############
# MONITORS #
############

load_monitors() {
  command -v hyprctl >/dev/null 2>&1 &&
    MONITORS_JSON="$(hyprctl monitors all -j 2>/dev/null)" &&
    jq empty <<<"$MONITORS_JSON" 2>/dev/null || {
    echo "No running Hyprland session." >&2
    exit 2
  }
}

# Works out a screen's ID, and the selector Hyprland will match it with (its description,
# or its port when the description can't tell it apart)
set_monitor_identity() {
  local output="$1" make="$2" model="$3" serial="$4" description="$5"
  local identity duplicate_count

  if [[ -z "$description" ]]; then
    # Headless outputs and some adapters have none, and "desc:" alone would match
    # every screen
    identity="|$output"
    MONITOR_SELECTOR="$output"
  elif [[ -n "$serial" ]]; then
    identity="$make|$model|$serial"
    MONITOR_SELECTOR="desc:$description"
  else
    duplicate_count="$(
      jq -r --arg description "$description" \
        '[.[] | select(.description == $description)] | length' <<<"$MONITORS_JSON"
    )"
    if [[ "$duplicate_count" -gt 1 ]]; then
      # Twin screens without a serial look the same: only their ports tell them apart
      identity="$description|$output"
      MONITOR_SELECTOR="$output"
    else
      identity="$description"
      MONITOR_SELECTOR="desc:$description"
    fi
  fi

  MONITOR_ID="$(printf '%s' "$identity" | sha256sum | cut -c1-16)"
}

# The screens plugged in, one per line: port, ID, selector, then the fields the jq
# array given asks for
screens() {
  local extra="${1:-[]}" output make model serial description rest
  while IFS=$'\x1f' read -r output make model serial description rest; do
    set_monitor_identity "$output" "$make" "$model" "$serial" "$description"
    printf '%s\x1f%s\x1f%s\x1f%s\n' "$output" "$MONITOR_ID" "$MONITOR_SELECTOR" "$rest"
  done < <(
    jq -r "$LOGICAL_SIZE"'
      .[] |
      select(.disabled != true) |
      [.name, (.make // ""), (.model // ""), (.serial // ""), .description] +
        ('"$extra"' | map(tostring)) |
      join("\u001f")
    ' <<<"$MONITORS_JSON"
  )
}

# The ID of the screen on a port
resolve_monitor() {
  local fields output make model serial description
  fields="$(
    jq -er --arg output "$1" '
      .[] |
      select(.name == $output and .disabled != true) |
      [.name, (.make // ""), (.model // ""), (.serial // ""), .description] |
      join("\u001f")
    ' <<<"$MONITORS_JSON"
  )" || fail "Unknown output: $1"
  IFS=$'\x1f' read -r output make model serial description <<<"$fields"
  set_monitor_identity "$output" "$make" "$model" "$serial" "$description"
}

# The mode to save, the way Hyprland spells it: a resolution alone gets the fastest rate
# the screen offers at that size, a resolution@rate only one it really offers
pick_mode() {
  local output="$1" requested="${2%Hz}" rate=""
  [[ "$requested" == "preferred" ]] && {
    printf 'preferred\n'
    return 0
  }
  [[ "$requested" == *@* ]] && rate="${requested#*@}"
  jq -er --arg output "$output" --arg resolution "${requested%%@*}" --arg rate "$rate" '
    .[] |
    select(.name == $output and .disabled != true) |
    [
      .availableModes[] |
      select(startswith($resolution + "@")) |
      sub("Hz$"; "") |
      { mode: ., rate: (sub("^.*@"; "") | tonumber) }
    ] |
    if $rate == "" then max_by(.rate)
    else map(select((.rate - ($rate | tonumber) | fabs) < 0.001)) | first
    end |
    select(. != null) |
    .mode
  ' <<<"$MONITORS_JSON"
}

#####################
# SLOTS, WORKSPACES #
#####################

# The lowest number from 1 to 10 no screen has yet
next_monitor_slot() {
  awk -F= '
    $1 ~ /^slot\./ && $2 ~ /^[0-9]+$/ { used[$2] = 1 }
    END {
      for (slot = 1; slot <= 10; slot++) {
        if (!used[slot]) {
          print slot
          exit
        }
      }
    }
  ' "$(state)"
}

# Giving a screen a number another one has swaps their numbers
write_monitor_slot() {
  local monitor_id="$1" new_slot="$2" current_slot occupant_id
  current_slot="$(read_value "slot.$monitor_id")"
  [[ "$current_slot" == "$new_slot" ]] && return 0
  occupant_id="$(
    awk -F= -v slot="$new_slot" '
      $1 ~ /^slot\./ && $2 == slot { sub(/^slot\./, "", $1); print $1; exit }
    ' "$(state)"
  )"
  write_values "slot.$monitor_id=$new_slot" ${occupant_id:+"slot.$occupant_id=$current_slot"}
}

workspace_is_assigned() {
  awk -F= -v wanted="$1" '
    $1 ~ /^workspaces\./ {
      count = split($2, values, ",")
      for (i = 1; i <= count; i++) {
        if (values[i] == wanted) found = 1
      }
    }
    END { exit !found }
  ' "$(state)"
}

# "3, 1,1" becomes "1,3"; "none" stays empty
normalize_workspace_list() {
  local list="$1"
  [[ "$list" == "none" ]] && return 0
  [[ "$list" =~ ^[0-9,[:space:]]+$ && "$list" =~ [0-9] ]] || return 1
  printf '%s\n' "$list" |
    tr ', ' '\n' |
    awk '
      NF == 0 { next }
      /^[0-9]+$/ && $1 >= 1 && $1 <= 2147483647 { print $1 + 0; next }
      { invalid = 1 }
      END { if (invalid) exit 1 }
    ' |
    sort -nu |
    paste -sd, -
}

# A workspace belongs to one screen only: claiming it takes it from the others
write_workspace_list() {
  rewrite_state -v target="workspaces.$1" -v requested="$2" '
    BEGIN {
      count = split(requested, requested_values, ",")
      for (i = 1; i <= count; i++) claimed[requested_values[i]] = 1
    }
    $1 ~ /^workspaces\./ {
      if ($1 == target) next
      kept = ""
      count = split($2, existing, ",")
      for (i = 1; i <= count; i++) {
        if (!(existing[i] in claimed) && existing[i] != "") {
          kept = kept (kept == "" ? "" : ",") existing[i]
        }
      }
      print $1 "=" (kept == "" ? "none" : kept)
      next
    }
    { print }
    END { print target "=" (requested == "" ? "none" : requested) }
  '
}

##########
# LAYOUT #
##########

# Placing A next to B, when B already hangs off A, would chase its own tail
would_create_layout_cycle() {
  local moved_id="$1" current_id="$2" relation seen=" "

  while [[ -n "$current_id" ]]; do
    # Reaching the moved screen, or a chain that already loops
    [[ "$current_id" != "$moved_id" && "$seen" != *" $current_id "* ]] || return 0
    seen+="$current_id "
    relation="$(read_value "relative.$current_id")"
    [[ "$relation" == *:?* ]] || break
    current_id="${relation#*:}"
  done

  return 1
}

# Turns the saved "left of / above…" relations into positions for the screens that are
# plugged in. A missing screen's neighbours hang off whoever is left, and everything
# is shifted back to 0,0 so no empty space remains. Hyprland only reloads when a
# position really changed.
reflow_layout() {
  local output id selector x y logical_width logical_height
  local min_x min_y updates=() changed=false
  declare -A active pos_x pos_y width height resolved visiting

  # The first screen up the chain of relations that's plugged in
  nearest_active_reference() {
    local current_id="$1" relation
    declare -A seen_reference

    while [[ -n "$current_id" && -z "${seen_reference[$current_id]:-}" ]]; do
      if [[ -n "${active[$current_id]:-}" ]]; then
        printf '%s\n' "$current_id"
        return 0
      fi
      seen_reference["$current_id"]=true
      relation="$(read_value "relative.$current_id")"
      [[ "$relation" == *:?* ]] || return 1
      current_id="${relation#*:}"
    done

    return 1
  }

  # Placed against its reference once that one is placed. A screen with no reference
  # plugged in roots what's left, at its saved spot or where Hyprland put it.
  resolve_layout_position() {
    local id="$1" relation direction reference_id saved_position

    [[ -n "${active[$id]:-}" && -z "${visiting[$id]:-}" ]] || return 1
    [[ -z "${resolved[$id]:-}" ]] || return 0
    visiting["$id"]=true

    relation="$(read_value "relative.$id")"
    direction="${relation%%:*}"
    reference_id=""
    if [[ "$relation" == *:?* && "$direction" =~ ^(left|right|above|below)$ ]]; then
      reference_id="$(nearest_active_reference "${relation#*:}" || true)"
    fi

    if [[ -n "$reference_id" ]] && resolve_layout_position "$reference_id"; then
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
      saved_position="$(read_value "position.$id")"
      if [[ "$saved_position" =~ ^-?[0-9]+x-?[0-9]+$ ]]; then
        pos_x["$id"]="${saved_position%%x*}"
        pos_y["$id"]="${saved_position#*x}"
      fi
    fi

    unset 'visiting[$id]'
    resolved["$id"]=true
    return 0
  }

  [[ "$(read_value layout)" == "custom" ]] || return 0
  load_monitors

  while IFS=$'\x1f' read -r output id selector x y logical_width logical_height; do
    active["$id"]=true
    pos_x["$id"]="$x"
    pos_y["$id"]="$y"
    width["$id"]="$logical_width"
    height["$id"]="$logical_height"
  done < <(screens '[.x, .y, (logical_size | map(floor) | .[])]')

  [[ ${#active[@]} -gt 0 ]] || return 0
  for id in "${!active[@]}"; do
    resolve_layout_position "$id" || continue
    if [[ -z "${min_x+x}" ]] || ((pos_x[$id] < min_x)); then
      min_x="${pos_x[$id]}"
    fi
    if [[ -z "${min_y+x}" ]] || ((pos_y[$id] < min_y)); then
      min_y="${pos_y[$id]}"
    fi
  done

  for id in "${!resolved[@]}"; do
    updates+=("position.$id=$((pos_x[$id] - min_x))x$((pos_y[$id] - min_y))")
    [[ "$(read_value "position.$id")" == "${updates[-1]#*=}" ]] || changed=true
  done

  [[ "$changed" == "true" ]] || return 0
  write_values "${updates[@]}"
  reload_hyprland
}

############
# HYPRLAND #
############

# The screen the pointer is on and where on it, as "name x y", empty when on none
pointer_spot() {
  local position
  position="$(hyprctl cursorpos 2>/dev/null)" || return 0
  hyprctl monitors -j | jq -r --argjson x "${position%%,*}" --argjson y "${position#*, }" "$LOGICAL_SIZE"'
    .[] | select(.disabled != true) |
    logical_size as [$w, $h] |
    select($x >= .x and $x < .x + $w and $y >= .y and $y < .y + $h) |
    "\(.name) \($x - .x) \($y - .y)"
  ' 2>/dev/null | head -n 1
}

# The pointer back on that screen at the same spot, or as close as its new size allows
restore_pointer() {
  local target
  target="$(hyprctl monitors -j | jq -r --arg name "$1" --argjson dx "$2" --argjson dy "$3" "$LOGICAL_SIZE"'
    .[] | select(.name == $name and .disabled != true) |
    logical_size as [$w, $h] |
    "\(.x + ([$dx, $w - 1] | min) | floor) \(.y + ([$dy, $h - 1] | min) | floor)"
  ')"
  [[ -n "$target" ]] || return 0
  hyprctl dispatch "hl.dsp.cursor.move({ x = ${target% *}, y = ${target#* } })" >/dev/null 2>&1 || true
}

# Without animations, so the windows don't slide across to the screens' new places
# (looknfeel.lua reads the flag), and with the pointer kept on its screen rather than
# left at the same point of a layout that moved. Then a reload that leaves the screens
# alone brings the animations back, once Hyprland has moved everything; it runs on its
# own, off the lock.
reload_hyprland() {
  local flag="${XDG_RUNTIME_DIR:-/tmp}/hyprpunk-still-reload" spot name dx dy
  command -v hyprctl >/dev/null 2>&1 || return 0
  spot="$(pointer_spot || true)"
  : >"$flag"
  hyprctl reload >/dev/null 2>&1 || true
  rm -f "$flag"
  if [[ -n "$spot" ]]; then
    read -r name dx dy <<<"$spot"
    restore_pointer "$name" "$dx" "$dy"
  fi
  (
    sleep 1
    hyprctl reload config-only >/dev/null 2>&1 || true
  ) 9>&- >/dev/null 2>&1 &
}

# A new size moves the screens: Hyprland takes it, then the custom layout is worked out
# again from the screens' new sizes
apply_geometry() {
  reload_hyprland
  reflow_layout
}

command="${1:-}"
case "$command" in
# A new screen gets a number, workspaces and its fastest rate; known ones are left alone
sync)
  expect 1 "$@"
  acquire_lock
  load_monitors
  changed=false
  while IFS=$'\x1f' read -r output id selector size; do
    updates=()
    [[ "$(read_value "selector.$id")" == "$selector" ]] || updates+=("selector.$id=$selector")
    slot="$(read_value "slot.$id")"
    if [[ ! "$slot" =~ ^([1-9]|10)$ ]]; then
      slot="$(next_monitor_slot)"
      [[ -n "$slot" ]] || fail "Unable to assign an output number: all numbers from 1 to 10 are already used."
      updates+=("slot.$id=$slot")
    fi
    if [[ -z "$(read_value "workspaces.$id")" ]]; then
      if workspace_is_assigned "$slot"; then
        updates+=("workspaces.$id=none")
      else
        updates+=("workspaces.$id=$slot")
      fi
    fi
    [[ -n "$(read_value "scale.$id")" ]] || updates+=("scale.$id=auto")
    if [[ -z "$(read_value "mode.$id")" ]]; then
      mode="$(pick_mode "$output" "$size" || true)"
      [[ -z "$mode" ]] || updates+=("mode.$id=$mode")
    fi
    if ((${#updates[@]})); then
      write_values "${updates[@]}"
      changed=true
    fi
  done < <(screens '[(.width | tostring) + "x" + (.height | tostring)]')
  [[ "$changed" == "false" ]] || reload_hyprland
  reflow_layout
  ;;
reflow)
  expect 1 "$@"
  acquire_lock
  reflow_layout
  ;;
# The screens plugged in with their saved settings, as JSON for the shell
info)
  expect 1 "$@"
  load_monitors
  while IFS=$'\x1f' read -r output id _; do
    printf '%s\x1f' "$output" "$id" \
      "$(read_value "mode.$id")" \
      "$(read_value "scale.$id")" \
      "$(read_value "slot.$id")" \
      "$(read_value "workspaces.$id")" \
      "$(read_value "relative.$id")"
    printf '\n'
  done < <(screens) | jq -Rn \
    --argjson monitors "$MONITORS_JSON" \
    --arg layout "$(read_value layout)" '
      {
        layout: (if $layout == "" then "auto" else $layout end),
        outputs: [
          inputs |
          split("\u001f") |
          . as $fields |
          ($monitors[] | select(.name == $fields[0])) as $monitor |
          {
            name: $fields[0],
            id: $fields[1],
            mode: $fields[2],
            scale: $fields[3],
            slot: $fields[4],
            workspaces: $fields[5],
            relative: $fields[6],
            description: $monitor.description,
            model: ($monitor.model // ""),
            width: $monitor.width,
            height: $monitor.height,
            refresh_rate: $monitor.refreshRate,
            current_scale: $monitor.scale,
            x: $monitor.x,
            y: $monitor.y,
            transform: $monitor.transform,
            focused: $monitor.focused,
            modes: $monitor.availableModes
          }
        ]
      }
    '
  ;;
# The same, to read in a terminal
status)
  expect 1 "$@"
  "$0" info | jq -r '
    (.outputs | map({ (.id): .name }) | add // {}) as $ports |
    "Layout: \(.layout)",
    (.outputs[] |
      "",
      "\(.name) (number \(.slot)): \(.description)",
      "  mode        \(if .mode == "" then "preferred" else .mode end), now \(.width)x\(.height) at \(.refresh_rate * 100 | round / 100) Hz",
      "  scale       \(if .scale == "" then "auto" else .scale end), now \(.current_scale)",
      "  workspaces  \(if .workspaces == "" then "none" else .workspaces end)",
      (select(.relative != "") |
        (.relative | split(":")) as [$side, $id] |
        "  placed      \($side) \($ports[$id] // "a screen not plugged in")"),
      "  modes       \(.modes | map(sub("Hz$"; "")) | join(" "))")
  '
  ;;
mode)
  expect 3 "$@"
  [[ "$3" == "preferred" || "$3" =~ ^[0-9]+x[0-9]+(@[0-9]+([.][0-9]+)?(Hz)?)?$ ]] ||
    fail "Invalid mode: $3"
  acquire_lock
  load_monitors
  resolve_monitor "$2"
  mode="$(pick_mode "$2" "$3")" || fail "Unsupported mode for $2: $3"
  write_values "mode.$MONITOR_ID=$mode"
  apply_geometry
  ;;
scale)
  expect 3 "$@"
  [[ "$3" =~ ^(auto|1|1[.]25|1[.]5|1[.]75|2)$ ]] || fail "Invalid scale: $3"
  acquire_lock
  load_monitors
  resolve_monitor "$2"
  write_values "scale.$MONITOR_ID=$3"
  apply_geometry
  ;;
slot)
  expect 3 "$@"
  [[ "$3" =~ ^([1-9]|10)$ ]] || fail "Output number must be between 1 and 10."
  acquire_lock
  load_monitors
  resolve_monitor "$2"
  write_monitor_slot "$MONITOR_ID" "$3"
  reload_hyprland
  ;;
workspaces)
  expect 3 "$@"
  workspaces="$(normalize_workspace_list "$3")" || fail "Invalid workspace list: $3"
  acquire_lock
  load_monitors
  resolve_monitor "$2"
  write_workspace_list "$MONITOR_ID" "$workspaces"
  reload_hyprland
  ;;
# Only the relation is saved: the positions all follow from it
position)
  expect 4 "$@"
  output="$2"
  direction="$3"
  reference="$4"
  [[ "$direction" =~ ^(left|right|above|below)$ ]] || fail "Invalid direction: $direction"
  acquire_lock
  load_monitors
  resolve_monitor "$reference"
  reference_id="$MONITOR_ID"
  resolve_monitor "$output"
  output_id="$MONITOR_ID"
  [[ "$output_id" != "$reference_id" ]] || fail "A screen can't be placed against itself."
  # Against the screen placed against it: the same layout, said the other way round, so
  # dragging either of two screens works
  if [[ "$(read_value "relative.$reference_id")" == *":$output_id" ]]; then
    case "$direction" in
    left) direction=right ;;
    right) direction=left ;;
    above) direction=below ;;
    below) direction=above ;;
    esac
    exec "$0" position "$reference" "$direction" "$output"
  fi
  if would_create_layout_cycle "$output_id" "$reference_id"; then
    fail "Unable to position $output relative to $reference: this would create a layout cycle."
  fi
  write_values layout=custom "relative.$output_id=$direction:$reference_id"
  reflow_layout
  ;;
# Forget the custom layout, Hyprland lines them up again
auto-layout)
  expect 1 "$@"
  acquire_lock
  write_values layout=auto
  delete_values '^(position|relative)[.]'
  reload_hyprland
  ;;
# Start over from scratch: every screen set up again as if just plugged in
reset)
  expect 1 "$@"
  acquire_lock
  rm -f "$STATE_FILE"
  if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors -j >/dev/null 2>&1; then
    "$0" sync
  fi
  ;;
# The state as it was before, kept for undo
try)
  (($# > 1)) || {
    usage >&2
    exit 1
  }
  acquire_lock
  mkdir -p "$(dirname "$BACKUP_FILE")"
  if [[ -f "$STATE_FILE" ]]; then
    cp -f "$STATE_FILE" "$BACKUP_FILE"
  else
    rm -f "$BACKUP_FILE"
  fi
  shift
  exec "$0" "$@"
  ;;
undo)
  expect 1 "$@"
  acquire_lock
  if [[ -f "$BACKUP_FILE" ]]; then
    cp -f "$BACKUP_FILE" "$STATE_FILE"
  else
    rm -f "$STATE_FILE"
  fi
  reload_hyprland
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
