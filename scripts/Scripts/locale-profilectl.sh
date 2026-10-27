#!/usr/bin/env bash

set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
LANGUAGE_FILE="$STATE_DIR/locale-language"
REGIONAL_FILE="$STATE_DIR/locale-regional"

usage() {
  echo "Usage: $0 {get-language|get-regional|list|set-language <us|fr>|set-regional <us|fr>|init [us|fr] [us|fr]|ensure}"
}

read_profile() {
  local file="$1" fallback="$2"
  local profile="$fallback"
  if [[ -r "$file" ]]; then
    IFS= read -r profile <"$file" || true
  fi
  case "$profile" in
  us | fr) printf '%s\n' "$profile" ;;
  *) printf '%s\n' "$fallback" ;;
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
  local target="$1" profile="$2" temporary
  temporary=$(mktemp --tmpdir="$STATE_DIR" "$(basename "$target").XXXXXX")
  printf '%s\n' "$profile" >"$temporary"
  mv -f "$temporary" "$target"
}

export_locale_environment() {
  local language_locale="$1" regional_locale="$2"
  local -a assignments

  export LANG="$language_locale"
  export LC_MESSAGES="$language_locale"
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

apply_profiles() {
  local language="$1" regional="$2" language_locale regional_locale
  profile_locale "$language" >/dev/null || {
    echo "Unsupported interface language: $language" >&2
    exit 2
  }
  profile_locale "$regional" >/dev/null || {
    echo "Unsupported regional format: $regional" >&2
    exit 2
  }

  language_locale=$(profile_locale "$language")
  regional_locale=$(profile_locale "$regional")
  mkdir -p "$STATE_DIR"
  write_profile "$LANGUAGE_FILE" "$language"
  write_profile "$REGIONAL_FILE" "$regional"
  export_locale_environment "$language_locale" "$regional_locale"
  reload_hyprland
  printf 'Locale profiles: interface %s, regional formats %s\n' \
    "$language_locale" "$regional_locale"
}

case "${1:-}" in
get-language) read_profile "$LANGUAGE_FILE" us ;;
get-regional) read_profile "$REGIONAL_FILE" fr ;;
list) printf 'us\nfr\n' ;;
set-language)
  [[ $# -eq 2 ]] || { usage >&2; exit 2; }
  apply_profiles "$2" "$(read_profile "$REGIONAL_FILE" fr)"
  ;;
set-regional)
  [[ $# -eq 2 ]] || { usage >&2; exit 2; }
  apply_profiles "$(read_profile "$LANGUAGE_FILE" us)" "$2"
  ;;
init)
  [[ $# -le 3 ]] || { usage >&2; exit 2; }
  apply_profiles "${2:-us}" "${3:-fr}"
  ;;
ensure)
  apply_profiles "$(read_profile "$LANGUAGE_FILE" us)" "$(read_profile "$REGIONAL_FILE" fr)"
  ;;
*) usage >&2; exit 2 ;;
esac
