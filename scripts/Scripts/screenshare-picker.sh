#!/usr/bin/env bash
# Screen share picker of xdg-desktop-portal-hyprland, set in ~/.config/hypr/xdph.conf.
# Asks the shell's own picker what to share and prints xdph's [SELECTION] line, or
# nothing when you cancel. Falls back to hyprland-share-picker without the shell.
#
# Usage: screenshare-picker.sh [--allow-token]

set -uo pipefail

allow_token=false
for arg in "$@"; do
  [ "$arg" = "--allow-token" ] && allow_token=true
done

fifo="${XDG_RUNTIME_DIR:-/tmp}/hyprpunk-screenshare-$$"
rm -f "$fifo"
mkfifo -m 600 "$fifo" || exit 1
trap 'rm -f "$fifo"' EXIT

# Opened both ways so the read doesn't wait for the shell to open it, only for its line
exec 3<>"$fifo"
# No shell running, or one too old to have the picker: the stock one
if ! qs -c hyprpunk ipc call screenshare pick "$fifo" "$allow_token" "${XDPH_WINDOW_SHARING_LIST:-}" >/dev/null 2>&1; then
  rm -f "$fifo"
  exec hyprland-share-picker "$@"
fi

# The app waits as long as you choose; past that, the shell surely went away
if read -r -t 600 answer <&3 && [ -n "$answer" ]; then
  printf '[SELECTION]%s\n' "$answer"
fi
