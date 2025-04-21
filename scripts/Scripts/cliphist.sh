#!/bin/bash

selected=$(cliphist list | cut -f2- | rofi -dmenu -p " Clipboard ")
if [[ -n "$selected" ]]; then
  id=$(cliphist list | grep -F "$selected" | head -n1 | cut -f1)
  cliphist decode "$id" | wl-copy
fi
