#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
DOTFILES_DIR="${DOTFILES_DIR:-$(realpath "$SCRIPT_DIR/../..")}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <generate|restore> [qt5|qt6|all]

  generate  Create missing Qt configurations without overwriting existing ones.
  restore   Restore the selected Qt configurations from the dotfiles defaults.

The default target is all.
EOF
}

write_qt5_config() {
  local target="$1"

  cat >"$target" <<EOF
[Appearance]
color_scheme_path=$CONFIG_HOME/qt5ct/colors/catppuccin-mocha-mauve.conf
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
style=kvantum-dark

[Fonts]
fixed="JetBrainsMono Nerd Font,9,-1,5,50,0,0,0,0,0,Regular"
general="JetBrainsMono Nerd Font,9,-1,5,50,0,0,0,0,0,Regular"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[Troubleshooting]
force_raster_widgets=1
EOF
}

write_qt6_config() {
  local target="$1"

  cat >"$target" <<EOF
[Appearance]
color_scheme_path=$CONFIG_HOME/qt6ct/colors/catppuccin-mocha-mauve.conf
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
style=kvantum-dark

[Fonts]
fixed="JetBrainsMono Nerd Font,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"
general="JetBrainsMono Nerd Font,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[Troubleshooting]
force_raster_widgets=1
EOF
}

configure_version() {
  local version="$1"
  local mode="$2"
  local config_dir="$CONFIG_HOME/${version}ct"
  local config_file="$config_dir/${version}ct.conf"
  local palette_source="$DOTFILES_DIR/$version/.config/${version}ct/colors/catppuccin-mocha-mauve.conf"
  local palette_target="$config_dir/colors/catppuccin-mocha-mauve.conf"
  local tmp

  if [[ ! -f "$palette_source" ]]; then
    echo "Palette not found: $palette_source" >&2
    return 1
  fi

  install -Dm644 "$palette_source" "$palette_target"

  if [[ "$mode" == "generate" && -e "$config_file" ]]; then
    echo "Keeping existing configuration: $config_file"
    return 0
  fi

  tmp="$(mktemp --tmpdir="$config_dir" "${version}ct.conf.XXXXXX")"
  "write_${version}_config" "$tmp"
  chmod 644 "$tmp"
  mv -f "$tmp" "$config_file"
  echo "${mode^}d configuration: $config_file"
}

main() {
  local mode="${1:-}"
  local target="${2:-all}"

  case "$mode" in
  generate | restore) ;;
  *)
    usage >&2
    exit 1
    ;;
  esac

  case "$target" in
  qt5) configure_version qt5 "$mode" ;;
  qt6) configure_version qt6 "$mode" ;;
  all)
    configure_version qt5 "$mode"
    configure_version qt6 "$mode"
    ;;
  *)
    usage >&2
    exit 1
    ;;
  esac
}

main "$@"
