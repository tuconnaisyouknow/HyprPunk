#!/bin/bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/system-info.sh
source "$script_dir/lib/system-info.sh"

already_warned=false

while true; do
  if ! bat_lvl=$(battery_capacity); then
    exit 0
  fi

  if [ "$bat_lvl" -le 20 ]; then
    if [ "$already_warned" = false ]; then
      notify-send -u critical -i /usr/share/icons/Papirus-Dark/32x32/devices/gnome-dev-battery.svg "Battery Low" "Level: ${bat_lvl}%"
      already_warned=true
    fi
  else
    already_warned=false
  fi

  sleep 30
done
