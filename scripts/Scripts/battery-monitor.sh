#!/bin/bash

already_warned=false

while true; do
  bat_lvl=$(cat /sys/class/power_supply/BAT0/capacity)

  if [ "$bat_lvl" -le 20 ]; then
    if [ "$already_warned" = false ]; then
      notify-send -u critical -i /usr/share/icons/rose-pine-moon-icons/32x32/devices/gnome-dev-battery.svg "Battery Low" "Level: ${bat_lvl}%"
      already_warned=true
    fi
  else
    already_warned=false
  fi

  sleep 30
done
