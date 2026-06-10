#!/usr/bin/env bash
set -euo pipefail

THEMES_DIR="$HOME/.dotfiles/sddm/themes"
SYSTEM_THEMES_DIR="/usr/share/sddm/themes"
SDDM_CONF_DIR="/etc/sddm.conf.d"
SDDM_CONF="$SDDM_CONF_DIR/theme.conf"

C_ACCENT='\033[38;2;203;166;247m'
C_DIM='\033[38;2;166;173;200m'
C_GREEN='\033[38;2;166;227;161m'
C_RED='\033[38;2;243;139;168m'
C_BOLD='\033[1m'
C_RESET='\033[0m'

trap 'printf "\033[0m"' EXIT

info() {
  printf "${C_ACCENT}${C_BOLD}==>${C_RESET} %s\n" "$1"
}

substep() {
  printf "    ${C_DIM}%s${C_RESET}\n" "$1"
}

success() {
  printf "${C_GREEN}${C_BOLD}OK${C_RESET} %s\n" "$1"
}

error() {
  printf "${C_RED}${C_BOLD}ERROR${C_RESET} %s\n" "$1" >&2
}

usage() {
  printf "Usage:\n" >&2
  printf "  %s install\n" "$(basename "$0")" >&2
  printf "  %s update\n" "$(basename "$0")" >&2
  printf "  %s <theme-name>\n" "$(basename "$0")" >&2
  printf "Available themes:\n" >&2
  find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort >&2
}

validate_theme_files() {
  local theme_name="$1"
  local theme_path="$THEMES_DIR/$theme_name"

  if [ ! -f "$theme_path/Main.qml" ] || [ ! -f "$theme_path/metadata.desktop" ] || [ ! -f "$theme_path/theme.conf" ]; then
    error "Theme '$theme_name' is missing required SDDM files"
    exit 1
  fi
}

install_missing_themes() {
  local installed_count=0
  sudo mkdir -p "$SYSTEM_THEMES_DIR"

  while IFS= read -r theme_path; do
    local theme_name
    theme_name="$(basename "$theme_path")"
    validate_theme_files "$theme_name"

    if [ -e "$SYSTEM_THEMES_DIR/$theme_name" ]; then
      substep "Already installed: $theme_name"
      continue
    fi

    substep "Installing: $theme_name"
    sudo cp -r "$theme_path" "$SYSTEM_THEMES_DIR/$theme_name"
    installed_count=$((installed_count + 1))
  done < <(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

  success "Installed $installed_count new theme(s)."
}

update_installed_themes() {
  sudo mkdir -p "$SYSTEM_THEMES_DIR"

  while IFS= read -r theme_path; do
    local theme_name
    theme_name="$(basename "$theme_path")"
    validate_theme_files "$theme_name"

    substep "Updating: $theme_name"
    sudo rm -rf "$SYSTEM_THEMES_DIR/$theme_name"
    sudo cp -r "$theme_path" "$SYSTEM_THEMES_DIR/$theme_name"
  done < <(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

  success "Themes updated."
}

set_current_theme() {
  local selected_theme="$1"
  local theme_path="$THEMES_DIR/$selected_theme"

  if [[ "$selected_theme" == *"/"* ]] || [[ "$selected_theme" == "."* ]]; then
    error "Invalid theme name: $selected_theme"
    exit 1
  fi

  if [ ! -d "$theme_path" ]; then
    error "Unknown theme: $selected_theme"
    usage
    exit 1
  fi

  validate_theme_files "$selected_theme"

  if [ ! -e "$SYSTEM_THEMES_DIR/$selected_theme" ]; then
    error "Theme '$selected_theme' is not installed in $SYSTEM_THEMES_DIR"
    printf "Run '%s install' first.\n" "$(basename "$0")" >&2
    exit 1
  fi

  sudo mkdir -p "$SDDM_CONF_DIR"

  if [ ! -f "$SDDM_CONF" ]; then
    printf "[Theme]\nCurrent=%s\n" "$selected_theme" | sudo tee "$SDDM_CONF" >/dev/null
  elif grep -q "^Current=" "$SDDM_CONF"; then
    sudo sed -i "s|^Current=.*|Current=$selected_theme|" "$SDDM_CONF"
  elif grep -q "^\[Theme\]" "$SDDM_CONF"; then
    sudo sed -i "/^\[Theme\]/a Current=$selected_theme" "$SDDM_CONF"
  else
    printf "\n[Theme]\nCurrent=%s\n" "$selected_theme" | sudo tee -a "$SDDM_CONF" >/dev/null
  fi

  success "Theme '$selected_theme' is now active."
}

if ! command -v sddm >/dev/null 2>&1; then
  error "SDDM is not installed."
  exit 1
fi

if [ ! -d "$THEMES_DIR" ]; then
  error "Themes directory not found: $THEMES_DIR"
  exit 1
fi

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

case "$1" in
install)
  info "Installing missing themes"
  install_missing_themes
  ;;
update)
  info "Updating installed themes"
  update_installed_themes
  ;;
*)
  info "Selecting theme '$1'"
  set_current_theme "$1"
  ;;
esac
