#!/usr/bin/env bash
# Saves how notifications behave: how long they stay when an app doesn't say, and which
# apps pop up out of the island. A muted app's notifications go straight to the center.
# The shell watches the file; its settings window and `hyprpunk notifications` come here.
#   notificationctl.sh get                   every setting, as key=value
#   notificationctl.sh set duration <s>      seconds a notification stays, 0 until you close it
#   notificationctl.sh mute|unmute <app>     by its desktop entry, or the name it sends without one
#   notificationctl.sh noticed <app>         lists a new app (the shell, on its first notification)
#   notificationctl.sh forget <app>          takes an app off the list
#   notificationctl.sh ensure                fills in what's missing (install.sh)
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
STATE_FILE="$STATE_DIR/notifications.conf"
LOCK_FILE="$STATE_FILE.lock"
DEFAULT_DURATION=5

usage() {
  cat <<EOF
Usage:
  $(basename "$0") get
  $(basename "$0") set duration <seconds>
  $(basename "$0") mute|unmute|noticed|forget <app>
  $(basename "$0") ensure
EOF
}

# Several notifications arriving together each list their app
acquire_lock() {
  mkdir -p "$STATE_DIR"
  exec 9>"$LOCK_FILE"
  flock -w 10 -x 9
}

# The duration, then each app as app=<name> (pops up) or muted=<name>, first seen first
DURATION="$DEFAULT_DURATION"
APPS=()
MUTED=()
load() {
  local key value
  [[ -r "$STATE_FILE" ]] || return 0
  while IFS='=' read -r key value; do
    if [[ "$key" == "duration" && "$value" =~ ^[0-9]+$ ]]; then
      DURATION="$value"
    elif [[ ("$key" == "app" || "$key" == "muted") && -n "$value" ]] && ! known "$value"; then
      APPS+=("$value")
      if [[ "$key" == "muted" ]]; then
        MUTED+=("$value")
      fi
    fi
  done <"$STATE_FILE"
}

known() {
  local app
  for app in "${APPS[@]}"; do
    [[ "$app" == "$1" ]] && return 0
  done
  return 1
}

muted() {
  local app
  for app in "${MUTED[@]}"; do
    [[ "$app" == "$1" ]] && return 0
  done
  return 1
}

print() {
  local app
  printf 'duration=%s\n' "$DURATION"
  for app in "${APPS[@]}"; do
    if muted "$app"; then
      printf 'muted=%s\n' "$app"
    else
      printf 'app=%s\n' "$app"
    fi
  done
}

# Written whole and swapped in, so the shell never reads half a file
save() {
  local temporary
  temporary=$(mktemp --tmpdir="$STATE_DIR" notifications.conf.XXXXXX)
  print >"$temporary"
  mv -f "$temporary" "$STATE_FILE"
}

# The names of an array but one, back into the array: without APPS "Discord"
without() {
  local -n names="$1"
  local kept=() name
  for name in "${names[@]}"; do
    [[ "$name" == "$2" ]] || kept+=("$name")
  done
  names=("${kept[@]}")
}

# A name on one line, since each app is a line of the file
valid_app() {
  [[ -n "$1" && "$1" != *$'\n'* ]]
}

command="${1:-}"
case "$command" in
get)
  [[ $# -eq 1 ]] || {
    usage >&2
    exit 1
  }
  load
  print
  ;;
set)
  [[ $# -eq 3 && "$2" == "duration" && "$3" =~ ^[0-9]+$ ]] || {
    usage >&2
    exit 1
  }
  acquire_lock
  load
  DURATION="$3"
  save
  ;;
mute | unmute | noticed | forget)
  [[ $# -eq 2 ]] && valid_app "$2" || {
    usage >&2
    exit 1
  }
  acquire_lock
  load
  case "$command" in
  noticed)
    known "$2" && exit 0
    APPS+=("$2")
    ;;
  mute)
    known "$2" || APPS+=("$2")
    muted "$2" || MUTED+=("$2")
    ;;
  unmute)
    known "$2" || APPS+=("$2")
    without MUTED "$2"
    ;;
  forget)
    without APPS "$2"
    without MUTED "$2"
    ;;
  esac
  save
  ;;
ensure)
  [[ $# -eq 1 ]] || {
    usage >&2
    exit 1
  }
  acquire_lock
  load
  [[ "$(print)" == "$(cat "$STATE_FILE" 2>/dev/null)" ]] || save
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
