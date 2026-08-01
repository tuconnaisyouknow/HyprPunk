#!/usr/bin/env bash

set -euo pipefail

THEME_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/catppuccin-keybindings.rasi"
SCRIPT_DIR="$HOME/Scripts/Rofi"

MODE="${1:-standalone}"
BACK="${2:-menu}"

if [[ $# -gt 2 || "$MODE" != "standalone" && "$MODE" != "menu" ]]; then
  echo "Usage: $0 [standalone|menu] [previous_menu]" >&2
  exit 2
fi

for command in hyprctl jq rofi; do
  if ! command -v "$command" >/dev/null 2>&1; then
    notify-send -u critical "Keybindings" "Required command not found: $command"
    exit 1
  fi
done

if ! bindings_json="$(hyprctl binds -j 2>/dev/null)"; then
  notify-send -u critical "Keybindings" "Unable to read the active Hyprland keybindings."
  exit 1
fi

format_bindings() {
  jq -r '
    def hasbit($mask; $bit): ((($mask / $bit) | floor) % 2) == 1;

    def modifiers($mask):
      [
        if hasbit($mask; 64) then "Super" else empty end,
        if hasbit($mask; 4) then "Ctrl" else empty end,
        if hasbit($mask; 8) then "Alt" else empty end,
        if hasbit($mask; 1) then "Shift" else empty end,
        if hasbit($mask; 16) then "Mod2" else empty end,
        if hasbit($mask; 32) then "Mod3" else empty end,
        if hasbit($mask; 128) then "Mod5" else empty end
      ];

    def workspace_key:
      try (.description | capture("workspace (?<number>[0-9]+)$").number
        | if . == "10" then "0" else . end)
      catch "Unknown";

    def friendly_key:
      if .key == "" then workspace_key
      elif .key == "mouse_down" then "Wheel down"
      elif .key == "mouse_up" then "Wheel up"
      elif .key == "mouse:272" then "Left mouse button"
      elif .key == "mouse:273" then "Right mouse button"
      elif .key == "ugrave" then "ù"
      elif .key == "semicolon" then ";"
      elif .key == "XF86AudioRaiseVolume" then "Volume up"
      elif .key == "XF86AudioLowerVolume" then "Volume down"
      elif .key == "XF86AudioMute" then "Volume mute"
      elif .key == "XF86AudioMicMute" then "Microphone mute"
      elif .key == "XF86TouchpadToggle" then "Touchpad toggle"
      elif .key == "XF86MonBrightnessUp" then "Brightness up"
      elif .key == "XF86MonBrightnessDown" then "Brightness down"
      elif .key == "XF86AudioNext" then "Media next"
      elif .key == "XF86AudioPause" then "Media pause"
      elif .key == "XF86AudioPlay" then "Media play"
      elif .key == "XF86AudioPrev" then "Media previous"
      elif .key == "SPACE" then "Space"
      elif (.key | test("^[[:alpha:]]$")) then (.key | ascii_upcase)
      else .key
      end;

    .[]
    | select(.has_description == true and (.description | length) > 0)
    | ((modifiers(.modmask) + [friendly_key]) | join(" + ")) as $shortcut
    | [$shortcut, .description]
    | @tsv
  ' <<<"$bindings_json" |
    while IFS=$'\t' read -r shortcut description; do
      printf '%s\t%s\n' "$shortcut" "$description"
    done
}

set +e
selected_index="$(format_bindings | rofi -dmenu -i -p " Keybindings" \
  -theme "$THEME_PATH" -no-custom -format i)"
rofi_status=$?
set -e

if [[ $rofi_status -ne 0 ]]; then
  if [[ "$MODE" == "menu" ]]; then
    exec "$SCRIPT_DIR/menu.sh" "$BACK"
  fi
  exit 0
fi

if [[ ! "$selected_index" =~ ^[0-9]+$ ]]; then
  notify-send -u critical "Keybindings" "Rofi returned an invalid selection."
  exit 1
fi

description="$(jq -r --argjson index "$selected_index" '
  [.[] | select(.has_description == true and (.description | length) > 0)]
  | .[$index].description // empty
' <<<"$bindings_json")"

if [[ -z "$description" ]]; then
  notify-send -u critical "Keybindings" "The selected keybinding no longer exists."
  exit 1
fi

quoted_description="$(jq -Rn --arg description "$description" '$description')"

if ! hyprctl eval "run_keybinding($quoted_description)" >/dev/null; then
  notify-send -u critical "Keybindings" "Unable to run: $description"
  exit 1
fi

exit 0
