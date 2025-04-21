#!/bin/bash

BACKLIGHT_PATH="/sys/class/backlight/intel_backlight"
max=$(cat "$BACKLIGHT_PATH/max_brightness")
current=$(cat "$BACKLIGHT_PATH/brightness")

# Calcul du pourcentage de luminosité
percent=$((current * 100 / max))

# Icônes de luminosité, du plus faible au plus fort
icons=("" "" "" "" "" "" "" "" "")

# Convertit le pourcentage (0-100) en index (0-8)
index=$((percent * 8 / 100))

# Limite de sécurité
[ "$index" -gt 8 ] && index=8

icon=${icons[$index]}

echo "$icon $percent%"

