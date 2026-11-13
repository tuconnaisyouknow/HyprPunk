#!/usr/bin/env bash
# Saves the launcher's pinned and hidden apps, by desktop entry: the pinned ones come
# first, in the order you pinned them, before what you use most; the hidden ones never
# show. The shell watches the file (AppLauncher.qml); its settings window and
# `hyprpunk launcher` come here.
#   launcherctl.sh get                 the apps, as pinned=<id> and hidden=<id>
#   launcherctl.sh pin|unpin <id>      pinning one shows it again
#   launcherctl.sh hide|show <id>      hiding one unpins it
#   launcherctl.sh ensure              writes an empty list the first time (install.sh)
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
STATE_FILE="$STATE_DIR/launcher.conf"
LOCK_FILE="$STATE_FILE.lock"

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") get
  $(basename "$0") pin|unpin|hide|show <desktop entry>
  $(basename "$0") ensure
USAGE
}

# Two quick clicks each change the file
acquire_lock() {
  mkdir -p "$STATE_DIR"
  exec 9>"$LOCK_FILE"
  flock -w 10 -x 9
}

PINNED=()
HIDDEN=()
load() {
  local key value
  [[ -r "$STATE_FILE" ]] || return 0
  while IFS='=' read -r key value; do
    if [[ -z "$value" ]]; then
      continue
    elif [[ "$key" == "pinned" ]] && ! listed PINNED "$value"; then
      PINNED+=("$value")
    elif [[ "$key" == "hidden" ]] && ! listed HIDDEN "$value"; then
      HIDDEN+=("$value")
    fi
  done <"$STATE_FILE"
}

# Whether an array holds a name: listed PINNED firefox
listed() {
  local -n names="$1"
  local name
  for name in "${names[@]}"; do
    [[ "$name" == "$2" ]] && return 0
  done
  return 1
}

# The names of an array but one, back into the array
without() {
  local -n names="$1"
  local kept=() name
  for name in "${names[@]}"; do
    [[ "$name" == "$2" ]] || kept+=("$name")
  done
  names=("${kept[@]}")
}

print() {
  local app
  for app in "${PINNED[@]}"; do
    printf 'pinned=%s\n' "$app"
  done
  for app in "${HIDDEN[@]}"; do
    printf 'hidden=%s\n' "$app"
  done
}

# Written whole and swapped in, so the shell never reads half a file
save() {
  local temporary
  temporary=$(mktemp --tmpdir="$STATE_DIR" launcher.conf.XXXXXX)
  print >"$temporary"
  mv -f "$temporary" "$STATE_FILE"
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
pin | unpin | hide | show)
  [[ $# -eq 2 && -n "$2" && "$2" != *$'\n'* ]] || {
    usage >&2
    exit 1
  }
  acquire_lock
  load
  case "$command" in
  pin)
    listed PINNED "$2" || PINNED+=("$2")
    without HIDDEN "$2"
    ;;
  unpin) without PINNED "$2" ;;
  hide)
    listed HIDDEN "$2" || HIDDEN+=("$2")
    without PINNED "$2"
    ;;
  show) without HIDDEN "$2" ;;
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
  [[ "$(print)" == "$(cat "$STATE_FILE" 2>/dev/null)" && -e "$STATE_FILE" ]] || save
  ;;
*)
  usage >&2
  exit 1
  ;;
esac
