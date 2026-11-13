#!/usr/bin/env bash
# Saves how screenshots and recordings are kept: whether a screenshot is saved, copied or
# both, the folders they're saved to, and what a recording hears and how smoothly it
# records. The shell watches the file (Screenshot.qml); its settings window and
# `hyprpunk capture` both come here.
#   capturectl.sh get                   every setting, as key=value
#   capturectl.sh set screenshots <both|copy|save>
#   capturectl.sh set screenshots.folder|recordings.folder <path>
#                                       empty for Screenshots in your pictures folder,
#                                       Recordings in your videos folder
#   capturectl.sh set audio <system|microphone|none>
#   capturectl.sh set framerate <0|30|60>     0 records only what changes
#   capturectl.sh ensure                fills in what's missing with the defaults (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/capture.conf"

declare -A DEFAULTS=(
  [screenshots]=both
  [audio]=system
  [framerate]=0
  [screenshots.folder]=
  [recordings.folder]=
)
KEYS=(screenshots screenshots.folder audio framerate recordings.folder)

valid() {
  case "$1" in
  screenshots) [[ "$2" =~ ^(both|copy|save)$ ]] ;;
  audio) [[ "$2" =~ ^(system|microphone|none)$ ]] ;;
  framerate) [[ "$2" =~ ^(0|30|60)$ ]] ;;
  # A full path on one line, or nothing for the usual folder
  *.folder) [[ -z "$2" || ("$2" == /* && "$2" != *$'\n'*) ]] ;;
  esac
}

settings_main "$@"
