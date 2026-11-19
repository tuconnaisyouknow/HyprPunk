#!/usr/bin/env bash
# The keyboard layout, any of XKB's that writes the Latin alphabet, and where the Vim keys sit: on Vim's own letters
# (h j k l), or on the home row, the key your right index rests on and the three to its
# right, whatever the layout writes there (j k l m on AZERTY).
# Hyprland, Neovim, zsh and the shell read the choice and the keys worked out from it;
# tmux, kitty, less and yazi get small generated files. All in
# $XDG_STATE_HOME/hyprpunk/keyboard (~/.local/state by default).
#   keyboard-layoutctl.sh get                                 the layout, its variant, the keys
#   keyboard-layoutctl.sh list                                the layouts: code, variant, name
#   keyboard-layoutctl.sh set <layout> [variant]              from the shell
#   keyboard-layoutctl.sh keys <vim|home>                     from the shell
#   keyboard-layoutctl.sh init <layout> [variant] [vim|home]  from install.sh, through sudo
#   keyboard-layoutctl.sh ensure                              rewrites the generated files only

set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
STATE_FILE="$STATE_DIR/keyboard-layout"
GENERATED_DIR="$STATE_DIR/keyboard"
KEYS_FILE="$GENERATED_DIR/keys"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LAYOUTS_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/hyprpunk/keyboard-layouts"
# XKB's own list of layouts: the one kept here is read again when this one changes
XKB_RULES="/usr/share/X11/xkb/rules/evdev.xml"
DOTFILES_DIR="$HOME/.dotfiles"
# Where libxkbcommon says which character each key symbol is
KEYSYMS="/usr/include/xkbcommon/xkbcommon-keysyms.h"

# Left, down, up, right, here and in every list below
readonly -a DIRECTIONS=(left down up right)
readonly -a VIM=(h j k l)
readonly -a VIM_SHIFT=(H J K L)
# The right hand's home keys, by position: the index's, then the three to its right
readonly -a HOME_KEYS=(AC07 AC08 AC09 AC10)
# What stands in for Ctrl + a key the terminal can't send
readonly -a STAND_INS=(F9 F10 F11 F12)

layout="us"
variant=""
place="vim"

usage() {
  echo "Usage: $0 {get|list|set <layout> [variant]|keys <vim|home>|init <layout> [variant] [vim|home]|ensure}"
}

###########
# CHOICES #
###########

# The file used to hold one word, fr or us, and fr meant AZERTY on its home row
read_state() {
  local line
  [[ -r "$STATE_FILE" ]] || return 0
  while IFS= read -r line; do
    case "$line" in
    layout=*) layout="${line#layout=}" ;;
    variant=*) variant="${line#variant=}" ;;
    keys=*) place="${line#keys=}" ;;
    fr) layout="fr" place="home" ;;
    esac
  done <"$STATE_FILE"
  [[ "$place" == "home" ]] || place="vim"
}

write_state() {
  printf 'layout=%s\nvariant=%s\nkeys=%s\n' "$layout" "$variant" "$place" >"$STATE_FILE.tmp.$$"
  mv -f "$STATE_FILE.tmp.$$" "$STATE_FILE"
}

# Every layout and variant XKB knows: code, variant, name, split by tabs
all_layouts() {
  xkbcli list 2>/dev/null | awk -F"'" '
    /^layouts:/ { inside = 1; next }
    /^[a-z_]+:/ { inside = 0 }
    !inside { next }
    /^- layout:/ { code = $2 }
    /^  variant:/ { variant = $2 }
    /^  description:/ { sub(/^  description: /, ""); print code "\t" variant "\t" $0 }
  '
}

# A layout that writes the Latin alphabet: at least half of a to z on its plain keys.
# The others have no h j k l, and none of the letters the shortcuts are named after.
writes_latin() {
  local letters
  letters="$(xkbcli compile-keymap --layout "$1" --variant "$2" 2>/dev/null |
    sed -nE '/^[[:space:]]*key <A[B-E][0-9]+>/{s/symbols\[[^]]*\]//; s/^[^[]*\[[[:space:]]*([^], ]+).*/\1/p}' |
    grep -cx '[a-z]')" || true
  ((letters >= 13))
}

# The layouts you can pick, the Latin ones. Reading each takes a few seconds in all, so
# the list is kept until XKB's changes.
list_layouts() {
  local line code rest
  if [[ ! -s "$LAYOUTS_FILE" || "$XKB_RULES" -nt "$LAYOUTS_FILE" ]]; then
    mkdir -p "${LAYOUTS_FILE%/*}"
    all_layouts | while IFS= read -r line; do
      code="${line%%$'\t'*}"
      rest="${line#*$'\t'}"
      if writes_latin "$code" "${rest%%$'\t'*}"; then
        printf '%s\n' "$line"
      fi
    done >"$LAYOUTS_FILE.tmp.$$"
    if [[ -s "$LAYOUTS_FILE.tmp.$$" ]]; then
      mv -f "$LAYOUTS_FILE.tmp.$$" "$LAYOUTS_FILE"
    else
      rm -f "$LAYOUTS_FILE.tmp.$$"
    fi
  fi
  [[ -r "$LAYOUTS_FILE" ]] && cat "$LAYOUTS_FILE"
  return 0
}

# The layout as you'd read it ("French (BEPO)"), or its code when XKB can't be asked
layout_name() {
  local name
  name="$(list_layouts | awk -F'\t' -v code="$layout" -v variant="$variant" \
    '$1 == code && $2 == variant { print $3; exit }')"
  printf '%s\n' "${name:-$layout${variant:+ ($variant)}}"
}

require_layout() {
  list_layouts | awk -F'\t' -v code="$1" -v variant="$2" \
    '$1 == code && $2 == variant { found = 1 } END { exit !found }' || {
    echo "Unknown keyboard layout, or not a Latin one: $1${2:+ ($2)}. See: $0 list" >&2
    exit 2
  }
}

############
# THE KEYS #
############

# A character from its code point, whatever the locale the script runs in
utf8() {
  local code="$1"
  if ((code < 0x80)); then
    printf "\\x$(printf '%x' "$code")"
  elif ((code < 0x800)); then
    printf "\\x$(printf '%x' $((0xC0 | code >> 6)))\\x$(printf '%x' $((0x80 | code & 0x3F)))"
  elif ((code < 0x10000)); then
    printf "\\x$(printf '%x' $((0xE0 | code >> 12)))\\x$(printf '%x' $((0x80 | code >> 6 & 0x3F)))\\x$(printf '%x' $((0x80 | code & 0x3F)))"
  else
    printf "\\x$(printf '%x' $((0xF0 | code >> 18)))\\x$(printf '%x' $((0x80 | code >> 12 & 0x3F)))\\x$(printf '%x' $((0x80 | code >> 6 & 0x3F)))\\x$(printf '%x' $((0x80 | code & 0x3F)))"
  fi
}

# The character a key symbol types (odiaeresis, U016F, Cyrillic_o), or nothing for a
# dead key or a key that types none
symbol_char() {
  local name="$1" code=""
  if [[ "$name" =~ ^U([0-9A-Fa-f]{4,6})$ ]]; then
    code="${BASH_REMATCH[1]}"
  elif [[ "$name" =~ ^0x01([0-9A-Fa-f]{6})$ ]]; then
    code="${BASH_REMATCH[1]}"
  elif [[ "$name" =~ ^[A-Za-z0-9_]+$ && -r "$KEYSYMS" ]]; then
    code="$(sed -nE "s/^#define XKB_KEY_$name +0x[0-9a-f]+ +\/\*[ (<]*U\+([0-9A-F]+) .*/\1/p" "$KEYSYMS" | head -n 1)"
  fi
  [[ -n "$code" ]] || return 1
  ((0x$code > 0x20 && 0x$code != 0x7F)) || return 1
  utf8 "$((0x$code))"
}

# What the layout writes on the four home keys, plain and with Shift, and the plain
# symbols' names. A key that types nothing keeps Vim's letter for its direction.
read_home_keys() {
  local keymap index symbols plain shifted
  home=("${VIM[@]}")
  home_shift=("${VIM_SHIFT[@]}")
  home_names=("${VIM[@]}")
  keymap="$(xkbcli compile-keymap --layout "$layout" --variant "$variant" 2>/dev/null)" || {
    echo "Warning: the layout couldn't be read, the home row keeps h j k l." >&2
    return 0
  }
  for index in 0 1 2 3; do
    symbols="$(grep -m 1 "key <${HOME_KEYS[index]}>" <<<"$keymap" |
      sed -E 's/symbols\[[^]]*\]//; s/^[^[]*\[//; s/\].*//; s/,/ /g')"
    read -r plain shifted _ <<<"$symbols" || true
    if home[index]="$(symbol_char "${plain:-}")"; then
      home_names[index]="$plain"
    else
      home[index]="${VIM[index]}"
    fi
    home_shift[index]="$(symbol_char "${shifted:-}")" || home_shift[index]="${VIM_SHIFT[index]}"
  done
}

index_of() {
  local wanted="$1" index=0 item
  shift
  for item in "$@"; do
    if [[ "$item" == "$wanted" ]]; then
      printf '%s\n' "$index"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

# Who does what once the keys have moved: each of the four takes its direction, and a
# letter of Vim's left free takes what the key at the end of its chain used to do (on
# AZERTY, m moves right, so h sets marks). Fills two lists, the keys and what they do.
permute() {
  local -n new="$1" old="$2" keys_out="$3" roles_out="$4"
  local index next found steps
  keys_out=("${new[@]}")
  roles_out=("${old[@]}")
  for index in 0 1 2 3; do
    index_of "${old[index]}" "${new[@]}" >/dev/null && continue
    next="$index"
    for steps in 1 2 3 4; do
      found="$(index_of "${new[next]}" "${old[@]}")" || break
      next="$found"
    done
    keys_out+=("${old[index]}")
    roles_out+=("${new[next]}")
  done
}

# Ctrl + a key as the terminal sends it: the letter, or its stand-in when there's no
# such code (Ctrl+M is Enter, Ctrl+I is Tab, and nothing but a letter has one)
control_key() {
  case "$1" in
  [abcdefghjklnopqrstuvwxyz]) printf '%s\n' "$1" ;;
  *) printf '%s\n' "${STAND_INS[$2]}" ;;
  esac
}

# Everything the generators and the apps need, worked out once
resolve_keys() {
  local index
  read_home_keys
  if [[ "$place" == "home" ]]; then
    keys=("${home[@]}")
    keys_shift=("${home_shift[@]}")
    names=("${home_names[@]}")
  else
    keys=("${VIM[@]}")
    keys_shift=("${VIM_SHIFT[@]}")
    names=("${VIM[@]}")
  fi
  control=()
  for index in 0 1 2 3; do
    control[index]="$(control_key "${keys[index]}" "$index")"
  done
  permute keys VIM moved roles
  permute keys_shift VIM_SHIFT moved_shift roles_shift
}

# The Ctrl keys the last choice gave tmux, to free them before the new ones
read_previous_control() {
  local line
  previous_control=()
  [[ -r "$KEYS_FILE" ]] || return 0
  while IFS= read -r line; do
    [[ "$line" == ctrl_*=* ]] && previous_control+=("${line#*=}")
  done <"$KEYS_FILE"
  return 0
}

##############
# GENERATORS #
##############

write_file() {
  local target="$1"
  umask 077
  cat >"$target.tmp.$$"
  mv -f "$target.tmp.$$" "$target"
}

# What Hyprland, Neovim, zsh and the shell read: the four keys, their symbols' names and
# their Ctrl form, the letters that took over a moved key's job (spare_h=m: h does what
# m did), and the home row's keys and the layout's name for the settings to show
generate_keys() {
  local index
  {
    for index in 0 1 2 3; do
      printf '%s=%s\n' "${DIRECTIONS[index]}" "${keys[index]}"
    done
    for index in 0 1 2 3; do
      printf 'name_%s=%s\n' "${DIRECTIONS[index]}" "${names[index]}"
    done
    for index in 0 1 2 3; do
      printf 'ctrl_%s=%s\n' "${DIRECTIONS[index]}" "${control[index]}"
    done
    for ((index = 4; index < ${#moved[@]}; index++)); do
      printf 'spare_%s=%s\n' "${moved[index]}" "${roles[index]}"
    done
    printf 'home=%s\n' "${home[*]}"
    printf 'layout_name=%s\n' "$(layout_name)"
  } | write_file "$KEYS_FILE"
}

# Kitty sends the stand-in for each Ctrl + key the terminal has no code for
generate_kitty() {
  local index key
  for index in 0 1 2 3; do
    [[ "${control[index]}" == F* ]] || continue
    key="${keys[index]}"
    [[ "$key" == "+" ]] && key="plus"
    printf 'map ctrl+%s send_key %s\n' "$key" "${control[index],,}"
  done | write_file "$GENERATED_DIR/kitty.conf"
}

# Less scrolls with the down and up keys, when they aren't Vim's already
generate_less() {
  local index key actions=([1]="forw-line" [2]="back-line")
  for index in 1 2; do
    key="${keys[index]}"
    [[ "$key" == "${VIM[index]}" ]] && continue
    [[ "$key" == [[:ascii:]] && "$key" != [[:alnum:]] ]] && key="\\$key"
    printf '%s %s\n' "$key" "${actions[index]}"
  done | write_file "$GENERATED_DIR/lesskey"
}

tmux_key() {
  if [[ "$1" == "'" ]]; then
    printf '"%s"' "$1"
  else
    printf "'%s'" "$1"
  fi
}

tmux_control() {
  if [[ "$1" == F* ]]; then
    printf '%s' "$1"
  else
    printf 'C-%s' "$1"
  fi
}

# tmux's copy mode starts again from its own keys, read from a server with no config,
# then each key that moved takes its new job. The pane keys and the session picker's
# scrolling follow the four keys.
generate_tmux() {
  local defaults="" line index key role command old
  local pattern='^bind-key[[:space:]]+(-r[[:space:]]+)?-T[[:space:]]+copy-mode-vi[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)$'
  local -A commands=()

  if command -v tmux >/dev/null 2>&1; then
    defaults="$(tmux -L hyprpunk-defaults -f /dev/null list-keys -T copy-mode-vi 2>/dev/null || true)"
  fi
  while IFS= read -r line; do
    [[ "$line" =~ $pattern ]] || continue
    key="${BASH_REMATCH[2]}"
    [[ "${#key}" -eq 2 && "$key" == \\* ]] && key="${key#\\}"
    commands["$key"]="${BASH_REMATCH[3]}"
  done <<<"$defaults"

  {
    if [[ -n "$defaults" ]]; then
      printf 'unbind-key -a -T copy-mode-vi\n%s\n' "$defaults"
      for index in "${!moved[@]}"; do
        key="${moved[index]}"
        role="${roles[index]}"
        [[ "$key" == "$role" ]] && continue
        command="${commands[$role]:-}"
        if [[ -n "$command" ]]; then
          printf 'bind-key -T copy-mode-vi %s %s\n' "$(tmux_key "$key")" "$command"
        else
          printf 'unbind-key -q -T copy-mode-vi %s\n' "$(tmux_key "$key")"
        fi
      done
    fi
    for old in "${previous_control[@]}" "${control[@]}"; do
      printf 'unbind-key -q -n %s\n' "$(tmux_control "$old")"
    done
    for index in 0 1 2 3; do
      printf 'set -g @vim_navigator_mapping_%s "%s"\n' "${DIRECTIONS[index]}" "$(tmux_control "${control[index]}")"
    done
    printf 'set -g @sessionx-bind-scroll-down %s\n' "$(tmux_key "alt-${keys[1]}")"
    printf 'set -g @sessionx-bind-scroll-up %s\n' "$(tmux_key "alt-${keys[2]}")"
  } | write_file "$GENERATED_DIR/tmux.conf"
}

# Yazi's config is a folder: the shared files are linked, and its default keymap is
# copied with every key that moved, Shift, Ctrl and Alt included. On Vim's letters it
# keeps its own.
generate_yazi() {
  local index plain="" shifted="" controls=""
  mkdir -p "$GENERATED_DIR/yazi"
  ln -sfn "$CONFIG_HOME/yazi/package.toml" "$GENERATED_DIR/yazi/package.toml"
  ln -sfn "$CONFIG_HOME/yazi/theme.toml" "$GENERATED_DIR/yazi/theme.toml"

  rm -f "$GENERATED_DIR/yazi/keymap.toml"
  [[ "${keys[*]}" == "${VIM[*]}" ]] && return 0

  for index in "${!moved[@]}"; do
    plain+="${roles[index]}"$'\t'"${moved[index]}"$'\n'
  done
  for index in "${!moved_shift[@]}"; do
    shifted+="${roles_shift[index]}"$'\t'"${moved_shift[index]}"$'\n'
  done
  for index in 0 1 2 3; do
    [[ "${control[index]}" == F* ]] && controls+="${keys[index]}"$'\t'"${control[index]}"$'\n'
  done

  PLAIN="$plain" SHIFTED="$shifted" CONTROLS="$controls" awk '
    function load(text, table,    lines, count, line, parts) {
      count = split(text, lines, "\n")
      for (line = 1; line <= count; line++)
        if (split(lines[line], parts, "\t") == 2)
          table[parts[1]] = parts[2]
    }
    function quoted(key) {
      gsub(/\\/, "\\\\", key)
      gsub(/"/, "\\\"", key)
      return key
    }
    function moved(key,    role) {
      if (key in plain)
        return quoted(plain[key])
      if (key in shifted)
        return quoted(shifted[key])
      role = substr(key, 4, length(key) - 4)
      if (key ~ /^<C-.>$/ && role in plain)
        return plain[role] in controls ? "<" controls[plain[role]] ">" : "<C-" quoted(plain[role]) ">"
      if (key ~ /^<A-.>$/ && role in plain)
        return "<A-" quoted(plain[role]) ">"
      return key
    }
    BEGIN {
      load(ENVIRON["PLAIN"], plain)
      load(ENVIRON["SHIFTED"], shifted)
      load(ENVIRON["CONTROLS"], controls)
    }
    # The header says what the default is, not what this copy is
    !started && /^#/ { next }
    { started = 1 }
    {
      cut = index($0, "run =")
      if ($0 !~ /on = / || cut == 0) {
        print
        next
      }
      head = substr($0, 1, cut - 1)
      out = ""
      while (match(head, /"[^"]*"/)) {
        out = out substr(head, 1, RSTART) moved(substr(head, RSTART + 1, RLENGTH - 2)) "\""
        head = substr(head, RSTART + RLENGTH)
      }
      print out head substr($0, cut)
    }
  ' "$DOTFILES_DIR/keyboard/yazi/keymap.toml" | write_file "$GENERATED_DIR/yazi/keymap.toml"
}

############
# APPLYING #
############

# Let whatever is running pick up the change right away
reload_apps() {
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    if ! timeout 2s hyprctl reload >/dev/null 2>&1; then
      echo "Warning: Hyprland did not reload in time." >&2
    fi
  fi
  if command -v pgrep >/dev/null 2>&1 && pgrep -x kitty >/dev/null 2>&1; then
    pkill -USR1 -x kitty >/dev/null 2>&1 || true
  fi
  if command -v tmux >/dev/null 2>&1 && timeout 2s tmux info >/dev/null 2>&1; then
    timeout 2s tmux source-file "$CONFIG_HOME/tmux/tmux.conf" >/dev/null 2>&1 || true
  fi
}

system_field() {
  localectl status 2>/dev/null | sed -n "s/^ *X11 $1: //p"
}

# The same layout for the login screen and the TTYs, keeping the keyboard's model and
# options. No password thanks to the polkit rule in keyboard/polkit, or through sudo
# when the installer asks ($1 = sudo).
apply_system_layout() {
  local prefix=() model options
  [[ "${1:-}" == sudo ]] && prefix=(sudo)
  command -v localectl >/dev/null 2>&1 || return 0
  [[ "$(system_field Layout)" == "$layout" && "$(system_field Variant)" == "$variant" ]] && return 0
  model="$(system_field Model)"
  options="$(system_field Options)"
  if ! "${prefix[@]}" localectl set-x11-keymap "$layout" "${model:-pc105}" "$variant" "$options"; then
    echo "Warning: the login screen and TTY keymap was not changed." >&2
  fi
}

apply() {
  mkdir -p "$STATE_DIR" "$GENERATED_DIR"
  read_previous_control
  resolve_keys
  generate_keys
  generate_kitty
  generate_less
  generate_tmux
  generate_yazi
  write_state
  reload_apps
  printf 'Keyboard layout: %s%s, Vim keys on %s\n' "$layout" "${variant:+ ($variant)}" "${keys[*]}"
}

case "${1:-}" in
get)
  read_state
  printf 'layout=%s\nvariant=%s\nkeys=%s\n' "$layout" "$variant" "$place"
  ;;
list) list_layouts ;;
set)
  [[ $# -eq 2 || $# -eq 3 ]] || {
    usage >&2
    exit 2
  }
  read_state
  require_layout "$2" "${3:-}"
  layout="$2"
  variant="${3:-}"
  apply
  apply_system_layout
  ;;
keys)
  [[ $# -eq 2 && ("$2" == "vim" || "$2" == "home") ]] || {
    usage >&2
    exit 2
  }
  read_state
  place="$2"
  apply
  ;;
init)
  [[ $# -ge 2 && $# -le 4 && ("${4:-vim}" == "vim" || "${4:-vim}" == "home") ]] || {
    usage >&2
    exit 2
  }
  require_layout "$2" "${3:-}"
  layout="$2"
  variant="${3:-}"
  place="${4:-vim}"
  apply
  apply_system_layout sudo
  ;;
ensure)
  read_state
  apply
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
