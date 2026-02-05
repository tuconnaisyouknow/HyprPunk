#!/bin/bash

# Récupère les interfaces réseau actives
# Format : DEVICE:TYPE:STATE:CONNECTION
active_conn=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev | grep ':connected:')

if echo "$active_conn" | grep -q ':wifi:'; then
    ssid=$(echo "$active_conn" | grep ':wifi:' | cut -d':' -f4)
    echo -e "  "
elif echo "$active_conn" | grep -q ':ethernet:'; then
    echo "󰈀  "
else
    echo "󰖪  "
fi

