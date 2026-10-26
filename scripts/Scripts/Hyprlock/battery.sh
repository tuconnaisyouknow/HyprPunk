#!/bin/bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/system-info.sh
source "$script_dir/../lib/system-info.sh"

if ! capacity=$(battery_capacity); then
  echo " AC"
  exit 0
fi

status=$(battery_status)

# Icônes de batterie par tranche de 10%
# De 󰂎 (0-9%) à 󰁹 (100%), avec l'éclair en charge
icons=("󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹")
charging_icons=("󰢟" "󰢜" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅")

# Calcule l'index d'icône à afficher
index=$((capacity / 10))
[ "$index" -gt 10 ] && index=10

# Choisit l'icône correspondante
icon=${icons[$index]}

# Si en charge ou pleine, la même jauge avec l'éclair
if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
  icon=${charging_icons[$index]}
fi

# Affiche l'icône suivie du pourcentage
echo "$icon $capacity%"
