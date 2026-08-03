#!/bin/bash

# Récupère la ligne avec "Volume" en ignorant les warnings
volume_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -i "Volume:")

# Si le son est muet
if echo "$volume_raw" | grep -q '\[MUTED\]'; then
  echo -e "  Mute"
  exit 0
fi

# Extrait le volume float (ex: 0.83)
volume_float=$(echo "$volume_raw" | awk '{ print $2 }')

# Calcule le pourcentage entier
volume_int=$(echo "$volume_float * 100" | bc -l | awk '{ printf "%d", $1 }')

# Convertit point en virgule (même si inutile ici car entier, mais pour cohérence FR)
volume_fr="${volume_int//./,}"

# Choix de l'icône selon le volume
if [ "$volume_int" -ge 66 ]; then
  icon=" "
elif [ "$volume_int" -ge 33 ]; then
  icon=" "
else
  icon=" "
fi

# Affichage final 🇫🇷
echo "$icon ${volume_fr}%"
