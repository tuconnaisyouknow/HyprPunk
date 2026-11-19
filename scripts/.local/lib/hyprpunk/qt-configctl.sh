#!/usr/bin/env bash
# Writes the Qt settings, for qt5ct, qt6ct and KDE apps: Kvantum, the HyprPunk colors
# matugen writes, the icon theme with the wallpaper's folders and the shell's font.
# They're written rather than linked because the apps rewrite their file whenever you
# touch a setting, which would scribble over the dotfiles, and the icon theme follows
# the wallpaper (foldersctl.sh writes them again for each new one).

set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ICON_THEME=$("$script_dir/foldersctl.sh" name)

usage() {
  cat <<EOF
Usage: $(basename "$0") <generate|restore> [qt5|qt6|kde|all]

  generate  Create missing Qt configurations without overwriting existing ones.
  restore   Restore the selected Qt configurations from the dotfiles defaults.

The default target is all.
EOF
}

# Same settings for both, only the font line is spelled differently by each Qt.
# The file dialogs go through the portal, so they open in the shell's file picker.
write_qt5_config() {
  local target="$1"

  cat >"$target" <<EOF
[Appearance]
color_scheme_path=$DATA_HOME/color-schemes/HyprPunk.colors
custom_palette=true
icon_theme=$ICON_THEME
standard_dialogs=xdgdesktopportal
style=kvantum

[Fonts]
fixed="HyprPunk Text,10,-1,5,50,0,0,0,0,0,Regular"
general="HyprPunk Text,10,-1,5,50,0,0,0,0,0,Regular"

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
color_scheme_path=$DATA_HOME/color-schemes/HyprPunk.colors
custom_palette=true
icon_theme=$ICON_THEME
standard_dialogs=xdgdesktopportal
style=kvantum

[Fonts]
fixed="HyprPunk Text,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"
general="HyprPunk Text,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"

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

# KDE apps you install (Okular, Kate…) take their icons and widget style from here
# rather than from qt6ct, so this points them at the same ones as the other Qt apps
write_kde_config() {
  local target="$1"

  cat >"$target" <<EOF
[Icons]
Theme=$ICON_THEME

[KDE]
widgetStyle=qt6ct-style
EOF
}

configure() {
  local target="$1"
  local mode="$2"
  local config_file config_dir tmp

  case "$target" in
  kde) config_file="$CONFIG_HOME/kdeglobals" ;;
  *) config_file="$CONFIG_HOME/${target}ct/${target}ct.conf" ;;
  esac
  config_dir=$(dirname "$config_file")
  mkdir -p "$config_dir"

  if [[ "$mode" == "generate" && -e "$config_file" ]]; then
    echo "Keeping existing configuration: $config_file"
    return 0
  fi

  # Write next to it then swap, so a half-written file never gets read
  tmp="$(mktemp --tmpdir="$config_dir" "$(basename "$config_file").XXXXXX")"
  "write_${target}_config" "$tmp"
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
  qt5 | qt6 | kde) configure "$target" "$mode" ;;
  all)
    configure qt5 "$mode"
    configure qt6 "$mode"
    configure kde "$mode"
    ;;
  *)
    usage >&2
    exit 1
    ;;
  esac
}

main "$@"
