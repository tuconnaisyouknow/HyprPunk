#!/usr/bin/env bash
# Picks the regional formats (dates, numbers, money). The interface is in English,
# whatever the formats: HyprPunk speaks one language, and so do the apps around it.
# Saved for Hyprland's env.lua, and passed on to systemd and D-Bus so the apps they
# start follow too. Apps already open keep theirs until restarted. The login screen's
# clock follows the formats too.
#   locale-profilectl.sh get | list
#   locale-profilectl.sh set <us|fr>    from the shell
#   locale-profilectl.sh init [us|fr]   from install.sh
#   locale-profilectl.sh ensure         re-applies the saved one

set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
# The one language of the interface
LANGUAGE_LOCALE="en_US.UTF-8"
REGIONAL_FILE="$STATE_DIR/locale-regional"

usage() {
  echo "Usage: $0 {get|list|set <us|fr>|init [us|fr]|ensure}"
}

# The saved choice, or the United States' when there's none
read_profile() {
  local profile="us"
  if [[ -r "$REGIONAL_FILE" ]]; then
    IFS= read -r profile <"$REGIONAL_FILE" || true
  fi
  case "$profile" in
  us | fr) printf '%s\n' "$profile" ;;
  *) printf 'us\n' ;;
  esac
}

profile_locale() {
  case "$1" in
  us) printf 'en_US.UTF-8\n' ;;
  fr) printf 'fr_FR.UTF-8\n' ;;
  *) return 2 ;;
  esac
}

write_profile() {
  local temporary
  temporary=$(mktemp --tmpdir="$STATE_DIR" "$(basename "$REGIONAL_FILE").XXXXXX")
  printf '%s\n' "$1" >"$temporary"
  mv -f "$temporary" "$REGIONAL_FILE"
}

export_locale_environment() {
  local regional_locale="$1"
  local -a assignments

  export LANG="$LANGUAGE_LOCALE"
  export LC_MESSAGES="$LANGUAGE_LOCALE"
  export LC_CTYPE="$regional_locale"
  export LC_NUMERIC="$regional_locale"
  export LC_TIME="$regional_locale"
  export LC_COLLATE="$regional_locale"
  export LC_MONETARY="$regional_locale"
  export LC_PAPER="$regional_locale"
  export LC_NAME="$regional_locale"
  export LC_ADDRESS="$regional_locale"
  export LC_TELEPHONE="$regional_locale"
  export LC_MEASUREMENT="$regional_locale"
  export LC_IDENTIFICATION="$regional_locale"
  unset LC_ALL

  assignments=(
    "LANG=$LANG"
    "LC_MESSAGES=$LC_MESSAGES"
    "LC_CTYPE=$LC_CTYPE"
    "LC_NUMERIC=$LC_NUMERIC"
    "LC_TIME=$LC_TIME"
    "LC_COLLATE=$LC_COLLATE"
    "LC_MONETARY=$LC_MONETARY"
    "LC_PAPER=$LC_PAPER"
    "LC_NAME=$LC_NAME"
    "LC_ADDRESS=$LC_ADDRESS"
    "LC_TELEPHONE=$LC_TELEPHONE"
    "LC_MEASUREMENT=$LC_MEASUREMENT"
    "LC_IDENTIFICATION=$LC_IDENTIFICATION"
  )

  # Apps launched from now on, by systemd or D-Bus, get the new locale
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user unset-environment LC_ALL >/dev/null 2>&1 || true
    systemctl --user set-environment "${assignments[@]}" >/dev/null 2>&1 ||
      echo "Warning: the systemd user environment was not updated." >&2
  fi

  if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment \
      LANG LC_MESSAGES LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY \
      LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION \
      >/dev/null 2>&1 || echo "Warning: the D-Bus environment was not updated." >&2
  fi
}

reload_hyprland() {
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    if ! timeout 2s hyprctl reload >/dev/null 2>&1; then
      echo "Warning: Hyprland did not reload in time." >&2
    fi
  fi
}

apply_profile() {
  local regional="$1" regional_locale
  regional_locale=$(profile_locale "$regional") || {
    echo "Unsupported regional formats: $regional" >&2
    exit 2
  }

  mkdir -p "$STATE_DIR"
  write_profile "$regional"
  export_locale_environment "$regional_locale"
  reload_hyprland
  printf 'Locale: interface %s, regional formats %s\n' "$LANGUAGE_LOCALE" "$regional_locale"
}

case "${1:-}" in
get) read_profile ;;
list) printf 'us\nfr\n' ;;
set)
  [[ $# -eq 2 ]] || {
    usage >&2
    exit 2
  }
  apply_profile "$2"
  # The login screen's clock follows too
  "$HOME/.local/lib/hyprpunk/wallpaperctl.sh" login ||
    echo "Warning: the login screen keeps its old clock." >&2
  ;;
init)
  [[ $# -le 2 ]] || {
    usage >&2
    exit 2
  }
  apply_profile "${2:-us}"
  ;;
ensure)
  apply_profile "$(read_profile)"
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
