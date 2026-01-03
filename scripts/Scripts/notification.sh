#!/bin/bash

count=$(swaync-client -c)

if [ "$count" -gt 0 ]; then
  echo "{\"text\":\"󱅫\",\"tooltip\":\"󰂚 notifications\"}"
else
  echo "{\"text\":\"󰂚\",\"tooltip\":\"󰂚 notifications\"}"
fi
