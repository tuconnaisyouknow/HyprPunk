#!/usr/bin/env bash
set -u

if [[ $# -gt 2 || "${1:-menu}" != "standalone" && "${1:-menu}" != "menu" ]]; then
  echo "Usage: $0 [standalone|menu] [previous_menu]"
  exit 1
fi

THEME_PATH="$HOME/.config/rofi/catppuccin-script.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"
DISPLAYCTL="$HOME/Scripts/displayctl.sh"
MODE="${1:-menu}"
BACK="${2:-menu}"

# Child monitor menus use this to return here while preserving whether the
# monitor menu was originally opened standalone or from the global menu.
export MONITOR_ROOT_MODE="${MONITOR_ROOT_MODE:-$MODE}"

if ! "$DISPLAYCTL" bootstrap; then
  notify-send -u critical "Unable to initialize the monitor state."
  exit 1
fi

choice="$(
  printf '%s\n' \
    "󰹑 Change resolution" \
    "󰓅 Change refresh rate" \
    "󰩨 Change scale" \
    "󰍺 Position an output" \
    "󰓡 Number outputs" \
    "󰖲 Assign workspaces" \
    "󱣲 Automatic layout" \
    "󰑓 Reset all settings" |
    rofi -i -dmenu -p "󰍹 Monitors" -theme "$THEME_PATH"
)"

if [[ -z "$choice" ]]; then
  if [[ "$MODE" == "menu" ]]; then
    exec "$SCRIPT_DIR/menu.sh" "$BACK"
  fi
  exit 0
fi

case "$choice" in
*resolution*) exec "$SCRIPT_DIR/monitor-resolution.sh" ;;
*refresh*) exec "$SCRIPT_DIR/monitor-frequency.sh" ;;
*scale*) exec "$SCRIPT_DIR/monitor-scale.sh" ;;
*Position*) exec "$SCRIPT_DIR/monitor-position.sh" ;;
*Number*) exec "$SCRIPT_DIR/monitor-slot.sh" ;;
*workspaces*) exec "$SCRIPT_DIR/monitor-workspaces.sh" ;;
*Automatic*) "$DISPLAYCTL" auto-layout ;;
*Reset*) exec "$SCRIPT_DIR/monitor-reset.sh" ;;
*) notify-send -u normal "This option doesn't exist." ;;
esac
