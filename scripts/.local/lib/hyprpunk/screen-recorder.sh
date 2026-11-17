#!/bin/bash
# The screen recording, run on its own rather than by the shell: it goes on while the
# shell reloads, where it would be cut dead and its file left unreadable, and can still
# be stopped by a shell that restarted. The shell only follows it (Screenshot.qml).
#   screen-recorder.sh start <screen> <file> [wf-recorder options]
#                              starts recording to the file, then follows it
#   screen-recorder.sh follow  prints the recording under way (its screen, when it
#                              started in ms since epoch, its file, tab-separated) and
#                              waits for its end; nothing and done at once without one
#   screen-recorder.sh stop    ends it, its file finished properly

dir="${XDG_RUNTIME_DIR:-/run/user/$UID}/hyprpunk"
# The recording under way: who runs it, its screen, when it started and its file.
state="$dir/recording"

follow() {
  local pid screen started file
  [ -r "$state" ] || exit 0
  {
    read -r pid
    read -r screen
    read -r started
    read -r file
  } <"$state"
  # Left behind by a recording that was killed
  if ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$state"
    exit 0
  fi
  printf '%s\t%s\t%s\n' "$screen" "$started" "$file"
  tail --pid="$pid" -f /dev/null
}

case "${1:-}" in
start)
  [ $# -ge 3 ] || exit 2
  screen=$2
  file=$3
  shift 3
  # One at a time
  [ -e "$state" ] && follow
  mkdir -p "$dir" "$(dirname "$file")"
  # In a session of its own, so it isn't taken down with the shell
  setsid "$0" run "$file" "$@" </dev/null >/dev/null 2>&1 &
  printf '%s\n' "$!" "$screen" "$(date +%s%3N)" "$file" >"$state"
  follow
  ;;
run)
  file=$2
  shift 2
  # The crop keeps the sides even, which the encoder needs
  wf-recorder -y -F "crop=trunc(iw/2)*2:trunc(ih/2)*2" -x yuv420p "$@" -f "$file" 2>"$state.log"
  rm -f "$state"
  if [ ! -s "$file" ]; then
    error=$(tail -n 1 "$state.log")
    notify-send -a "Screen recording" "Recording failed" "${error:-wf-recorder could not record the screen}"
  fi
  rm -f "$state.log"
  ;;
follow)
  follow
  ;;
stop)
  [ -r "$state" ] || exit 0
  read -r pid <"$state"
  # An interrupt, so wf-recorder finishes the file properly
  pkill -INT -P "$pid" -x wf-recorder
  ;;
*)
  printf 'Usage: %s start <screen> <file> [options] | follow | stop\n' "$0" >&2
  exit 2
  ;;
esac
