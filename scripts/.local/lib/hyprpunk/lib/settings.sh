#!/bin/bash
# The settings files the shell's settings window changes, as key=value lines, meant to be
# sourced by their scripts (powerctl.sh, capturectl.sh). Each one sets STATE_FILE, KEYS
# (in order), DEFAULTS and a valid <key> <value> function, then hands its arguments to
# settings_main, which answers get, set <key> <value> and ensure.

declare -A SETTINGS

# The saved settings over the defaults, anything unknown or invalid left out
settings_load() {
  local key value
  for key in "${KEYS[@]}"; do
    SETTINGS[$key]="${DEFAULTS[$key]}"
  done
  [[ -r "$STATE_FILE" ]] || return 0
  while IFS='=' read -r key value; do
    if [[ -v "DEFAULTS[$key]" ]] && valid "$key" "$value"; then
      SETTINGS[$key]="$value"
    fi
  done <"$STATE_FILE"
}

settings_print() {
  local key
  for key in "${KEYS[@]}"; do
    printf '%s=%s\n' "$key" "${SETTINGS[$key]}"
  done
}

# Written whole and swapped in, so the shell never reads half a file
settings_save() {
  local directory temporary
  directory=$(dirname "$STATE_FILE")
  mkdir -p "$directory"
  temporary=$(mktemp --tmpdir="$directory" "$(basename "$STATE_FILE").XXXXXX")
  settings_print >"$temporary"
  mv -f "$temporary" "$STATE_FILE"
}

settings_usage() {
  cat <<EOF
Usage:
  $(basename "$0") get
  $(basename "$0") set <key> <value>
  $(basename "$0") ensure
Keys: ${KEYS[*]}
EOF
}

settings_main() {
  case "${1:-}" in
  get)
    [[ $# -eq 1 ]] || {
      settings_usage >&2
      return 1
    }
    settings_load
    settings_print
    ;;
  set)
    [[ $# -eq 3 && -v "DEFAULTS[$2]" ]] && valid "$2" "$3" || {
      settings_usage >&2
      return 1
    }
    settings_load
    SETTINGS[$2]="$3"
    settings_save
    ;;
  ensure)
    [[ $# -eq 1 ]] || {
      settings_usage >&2
      return 1
    }
    settings_load
    [[ "$(settings_print)" == "$(cat "$STATE_FILE" 2>/dev/null)" ]] || settings_save
    ;;
  *)
    settings_usage >&2
    return 1
    ;;
  esac
}
