#!/bin/bash

BATTERY_PATH="/sys/class/power_supply/BAT0"
capacity=$(cat "$BATTERY_PATH/capacity")
status=$(cat "$BATTERY_PATH/status")

# Icônes de batterie par tranche de 10%
# De 󰁹 (0-9%) à 󰂎 (100%)
icons=( "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" )

# Calcule l'index d'icône à afficher
index=$((capacity / 10))
[ "$index" -gt 10 ] && index=10

# Choisit l'icône correspondante
icon=${icons[$index]}

# Si en charge ou pleine, remplacer par l'icône de charge
if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
    icon=""  # Icône de charge
fi

# Affiche l'icône suivie du pourcentage
echo "$icon $capacity%"

