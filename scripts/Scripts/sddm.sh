#!/usr/bin/env bash
# Installs the login screen themes, one per subtheme, and what lets your wallpaper pick
# among them. Each theme is the shared base (sddm/base) with its own video and name on
# top. They're copied rather than linked: SDDM runs as its own user and can't read your home.
#   sddm.sh install   copies the themes that aren't there yet
#   sddm.sh update    copies them all again, after you edited one
set -euo pipefail

# The repository this script was linked from, wherever you cloned it
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_DIR="$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)"
BASE_DIR="$DOTFILES_DIR/sddm/base"
THEMES_DIR="$DOTFILES_DIR/sddm/themes"
SYSTEM_THEMES_DIR="/usr/share/sddm/themes"

# Catppuccin colors for the output
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
}

# SDDM needs these three files to load a theme: the base brings two, the theme its name
validate_theme_files() {
  local theme_name="$1"
  local theme_path="$THEMES_DIR/$theme_name"

  if [ ! -f "$BASE_DIR/Main.qml" ] || [ ! -f "$BASE_DIR/theme.conf" ] || [ ! -f "$theme_path/metadata.desktop" ]; then
    error "Theme '$theme_name' is missing required SDDM files"
    exit 1
  fi
}

# The base first, so a theme can replace any of its files with its own
copy_theme() {
  local theme_name="$1"
  local target="$SYSTEM_THEMES_DIR/$theme_name"

  sudo mkdir -p "$target"
  sudo cp -r "$BASE_DIR/." "$target/"
  sudo cp -r "$THEMES_DIR/$theme_name/." "$target/"
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
    copy_theme "$theme_name"
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
    sudo rm -rf "${SYSTEM_THEMES_DIR:?}/$theme_name"
    copy_theme "$theme_name"
  done < <(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

  success "Themes updated."
}

# wallpaperctl.sh picks the login screen through this tool and its polkit rule. Copied
# and owned by root: a link into your home would let anything you run act as root.
install_login_screen_access() {
  sudo install -Dm755 "$DOTFILES_DIR/sddm/hyprpunk-login-screen" /usr/local/bin/hyprpunk-login-screen
  sudo install -Dm644 "$DOTFILES_DIR/sddm/polkit/50-hyprpunk-login-screen.rules" \
    /etc/polkit-1/rules.d/50-hyprpunk-login-screen.rules
  substep "Installed the login screen access for your wallpaper"
}

if ! command -v sddm >/dev/null 2>&1; then
  error "SDDM is not installed."
  exit 1
fi

for dir in "$BASE_DIR" "$THEMES_DIR"; do
  if [ ! -d "$dir" ]; then
    error "Directory not found: $dir"
    exit 1
  fi
done

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

case "$1" in
install)
  info "Installing missing themes"
  install_missing_themes
  install_login_screen_access
  ;;
update)
  info "Updating installed themes"
  update_installed_themes
  install_login_screen_access
  ;;
*)
  usage
  exit 1
  ;;
esac
