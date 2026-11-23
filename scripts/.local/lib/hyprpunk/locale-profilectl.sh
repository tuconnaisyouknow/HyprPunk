#!/usr/bin/env bash
# Picks the regional formats (dates, numbers, money, sorting): any UTF-8 locale glibc
# supports, all of them installed by the glibc-locales package. The interface is in
# English, whatever the formats: HyprPunk speaks one language, and so do the apps around
# it. Saved for Hyprland's env.lua, with its name for the settings, and passed on to
# systemd and D-Bus so the apps they start follow too. Apps already open keep theirs
# until restarted. The login screen's clock follows the formats too.
#   locale-profilectl.sh get | list         the locale, or every one with its name
#   locale-profilectl.sh set <locale>       from the shell ("de_DE" or "de_DE.UTF-8")
#   locale-profilectl.sh init [locale]      from install.sh
#   locale-profilectl.sh ensure             re-applies the saved one

set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
# The one language of the interface, and the formats until you pick yours
LANGUAGE_LOCALE="en_US.UTF-8"
REGIONAL_FILE="$STATE_DIR/locale-regional"
NAME_FILE="$STATE_DIR/locale-name"
# Every locale glibc can build, and where each one says what it's called
SUPPORTED="/usr/share/i18n/SUPPORTED"
DEFINITIONS="/usr/share/i18n/locales"

usage() {
  echo "Usage: $0 {get|list|set <locale>|init [locale]|ensure}"
}

# The UTF-8 locales, as glibc names them ("de_DE.UTF-8", "sr_RS@latin"). C has no
# region, so it isn't one.
supported_locales() {
  awk '$2 == "UTF-8" && $1 !~ /^C\./ { print $1 }' "$SUPPORTED"
}

# A locale as you'd type it, or nothing when glibc doesn't have it: "de_DE" is
# de_DE.UTF-8, while "ta_LK" is UTF-8 under its bare name.
resolve_locale() {
  supported_locales | awk -v wanted="$1" '$1 == wanted || $1 == wanted ".UTF-8" { print; exit }'
}

# Each locale with its name, from its own definition: "French (France)", and its
# variant after the country when it has one, "Serbian (Serbia, Latin)".
locale_names() {
  local -a files=()
  local locale
  for locale in "$@"; do
    files+=("$DEFINITIONS/${locale%.UTF-8}")
  done

  awk -F'"' -v locales="$*" '
    BEGIN { split(locales, locale, " ") }
    /^LC_IDENTIFICATION/ { inside = 1; language = territory = "" }
    inside && /^language/ { language = $2 }
    inside && /^territory/ { territory = $2 }
    inside && /^END LC_IDENTIFICATION/ {
      inside = 0
      name = locale[++count]
      where = territory
      if (name ~ /@/) {
        variant = name
        sub(/.*@/, "", variant)
        where = where (where != "" ? ", " : "") toupper(substr(variant, 1, 1)) substr(variant, 2)
      }
      printf "%s\t%s%s\n", name, language, where != "" ? " (" where ")" : ""
    }
  ' "${files[@]}"
}

# The saved choice, or the default when there's none. us and fr were the only two
# choices once, saved by those names.
read_profile() {
  local saved="" locale
  if [[ -r "$REGIONAL_FILE" ]]; then
    IFS= read -r saved <"$REGIONAL_FILE" || true
  fi
  case "$saved" in
  us) saved="en_US" ;;
  fr) saved="fr_FR" ;;
  esac
  locale=$(resolve_locale "$saved")
  printf '%s\n' "${locale:-$LANGUAGE_LOCALE}"
}

# Swapped in whole, so the shell and Hyprland never read half a file
write_state() {
  local temporary
  temporary=$(mktemp --tmpdir="$STATE_DIR" "$(basename "$1").XXXXXX")
  printf '%s\n' "$2" >"$temporary"
  mv -f "$temporary" "$1"
}

export_locale_environment() {
  local regional_locale="$1"
  local -a assignments

  # Characters stay the language's too: they're no format, and a Turkish i would
  # change what every script's lowercase gives.
  export LANG="$LANGUAGE_LOCALE"
  export LC_MESSAGES="$LANGUAGE_LOCALE"
  export LC_CTYPE="$LANGUAGE_LOCALE"
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
  local regional_locale
  regional_locale=$(resolve_locale "$1")
  [[ -n "$regional_locale" ]] || {
    echo "Unsupported regional formats: $1 (see $0 list)" >&2
    exit 2
  }

  mkdir -p "$STATE_DIR"
  write_state "$REGIONAL_FILE" "$regional_locale"
  write_state "$NAME_FILE" "$(locale_names "$regional_locale" | cut -f2)"
  export_locale_environment "$regional_locale"
  reload_hyprland
  printf 'Locale: interface %s, regional formats %s\n' "$LANGUAGE_LOCALE" "$regional_locale"
}

case "${1:-}" in
get) read_profile ;;
list)
  mapfile -t locales < <(supported_locales)
  locale_names "${locales[@]}"
  ;;
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
  apply_profile "${2:-$LANGUAGE_LOCALE}"
  ;;
ensure)
  apply_profile "$(read_profile)"
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
