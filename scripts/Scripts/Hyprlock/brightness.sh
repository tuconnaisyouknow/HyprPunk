#!/bin/bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/system-info.sh
source "$script_dir/../lib/system-info.sh"

if ! percent=$(backlight_percent); then
    echo " N/A"
    exit 0
fi

# Icônes de luminosité, du plus faible au plus fort
icons=("" "" "" "" "" "" "" "" "")

# Convertit le pourcentage (0-100) en index (0-8)
index=$((percent * 8 / 100))

# Limite de sécurité
[ "$index" -gt 8 ] && index=8

icon=${icons[$index]}

echo "$icon $percent%"
