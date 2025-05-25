#!/bin/bash

# Path to the Hyprland configuration directory
CONFIG_DIR="$HOME/.config/hypr"

# Name of the touchpad configuration file
TOUCHPAD_CONFIG="touchpad.conf"

# Full path to the touchpad configuration file
CONFIG_FILE="$CONFIG_DIR/$TOUCHPAD_CONFIG"

# Check if the touchpad is currently enabled or disabled
enabled=$(grep -o "enabled\s*=\s*[01]" "$CONFIG_FILE")

# Toggle the touchpad state
if [ "$enabled" == "enabled = 0" ]; then
  sed -i "s/enabled\s*=\s*0/enabled = 1/" "$CONFIG_FILE"
  state="enabled"
else
  sed -i "s/enabled\s*=\s*1/enabled = 0/" "$CONFIG_FILE"
  state="disabled"
fi

if [ "$state" == "enabled" ]; then
  notify-send -u low -i /usr/share/icons/rose-pine-moon-icons/32x32/devices/gnome-dev-mouse-optical.svg "Mouse toogle" "✅ Enabled"
else
  notify-send -u low -i /usr/share/icons/rose-pine-moon-icons/32x32/devices/gnome-dev-mouse-optical.svg "Mouse toogle" "❌ Disabled"
fi
