#!/usr/bin/env bash

set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/hyprpunk"
STATE_FILE="$STATE_DIR/keyboard-layout"
GENERATED_DIR="${HYPRPUNK_KEYBOARD_RUNTIME_DIR:-$HOME/.local/state/hyprpunk/keyboard}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_DIR="$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)"

usage() {
  echo "Usage: $0 {get|list|set <fr|us>|toggle|init [fr|us]|ensure}"
}

# set, toggle and init also change the system keymap (login screen and TTYs);
# ensure only regenerates the session's files.

get_layout() {
  local layout="us"
  if [[ -r "$STATE_FILE" ]]; then
    IFS= read -r layout <"$STATE_FILE" || true
  fi
  case "$layout" in
    fr|us) printf '%s\n' "$layout" ;;
    *) printf 'us\n' ;;
  esac
}

write_file() {
  local target="$1"
  local temporary="$target.tmp.$$"
  umask 077
  sed 's/^[[:space:]]*//' >"$temporary"
  mv -f "$temporary" "$target"
}

generate_common() {
  local layout="$1"
  mkdir -p "$GENERATED_DIR/yazi"

  ln -sfn "$CONFIG_HOME/yazi/package.toml" "$GENERATED_DIR/yazi/package.toml"
  ln -sfn "$CONFIG_HOME/yazi/theme.toml" "$GENERATED_DIR/yazi/theme.toml"
  ln -sfn "$CONFIG_HOME/yazi/themes" "$GENERATED_DIR/yazi/themes"

  if [[ "$layout" == "fr" ]]; then
    ln -sfn "$DOTFILES_DIR/keyboard/yazi/fr.toml" "$GENERATED_DIR/yazi/keymap.toml"
  else
    unlink "$GENERATED_DIR/yazi/keymap.toml" 2>/dev/null || true
  fi
}

generate_fr() {
  write_file "$GENERATED_DIR/tmux.conf" <<'EOF'
    unbind-key -q -n C-h
    unbind-key -q -n C-j
    unbind-key -q -n C-k
    unbind-key -q -n C-l
    unbind-key -q -n F12
    unbind-key -T copy-mode-vi h
    unbind-key -T copy-mode-vi j
    unbind-key -T copy-mode-vi k
    unbind-key -T copy-mode-vi l
    unbind-key -T copy-mode-vi m
    bind-key -T copy-mode-vi j send -X cursor-left
    bind-key -T copy-mode-vi k send -X cursor-down
    bind-key -T copy-mode-vi l send -X cursor-up
    bind-key -T copy-mode-vi m send -X cursor-right
    set -g @vim_navigator_mapping_left "C-j"
    set -g @vim_navigator_mapping_down "C-k"
    set -g @vim_navigator_mapping_up "C-l"
    set -g @vim_navigator_mapping_right "F12"
EOF
  write_file "$GENERATED_DIR/kitty.conf" <<'EOF'
    map ctrl+m send_key f12
EOF
  write_file "$GENERATED_DIR/lesskey" <<'EOF'
    k forw-line
    l back-line
EOF
}

generate_us() {
  write_file "$GENERATED_DIR/tmux.conf" <<'EOF'
    unbind-key -q -n C-h
    unbind-key -q -n C-j
    unbind-key -q -n C-k
    unbind-key -q -n C-l
    unbind-key -q -n F12
    unbind-key -T copy-mode-vi h
    unbind-key -T copy-mode-vi j
    unbind-key -T copy-mode-vi k
    unbind-key -T copy-mode-vi l
    unbind-key -T copy-mode-vi m
    bind-key -T copy-mode-vi h send -X cursor-left
    bind-key -T copy-mode-vi j send -X cursor-down
    bind-key -T copy-mode-vi k send -X cursor-up
    bind-key -T copy-mode-vi l send -X cursor-right
    set -g @vim_navigator_mapping_left "C-h"
    set -g @vim_navigator_mapping_down "C-j"
    set -g @vim_navigator_mapping_up "C-k"
    set -g @vim_navigator_mapping_right "C-l"
EOF
  : >"$GENERATED_DIR/kitty.conf"
  : >"$GENERATED_DIR/lesskey"
}

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

# The system keymap, for SDDM's login screen and the TTYs (localectl also sets the
# console's from the X11 layout), the model and options kept. Through polkit without
# a password (keyboard/polkit, installed by install.sh), or through sudo with
# $2 = sudo (the installer).
apply_system_layout() {
  local layout="$1" prefix=() model options
  [[ "${2:-}" == sudo ]] && prefix=(sudo)
  command -v localectl >/dev/null 2>&1 || return 0
  [[ "$(system_field Layout)" == "$layout" ]] && return 0
  model="$(system_field Model)"
  options="$(system_field Options)"
  if ! "${prefix[@]}" localectl set-x11-keymap "$layout" "${model:-pc105}" "" "$options"; then
    echo "Warning: the login screen and TTY keymap was not changed." >&2
  fi
}

apply_layout() {
  local layout="$1"
  case "$layout" in
    fr|us) ;;
    *) echo "Unsupported keyboard layout: $layout" >&2; exit 2 ;;
  esac

  mkdir -p "$STATE_DIR" "$GENERATED_DIR"
  generate_common "$layout"
  "generate_$layout"
  printf '%s\n' "$layout" >"$STATE_FILE.tmp.$$"
  mv -f "$STATE_FILE.tmp.$$" "$STATE_FILE"
  reload_apps
  printf 'Keyboard layout: %s (%s navigation)\n' "${layout^^}" "$([[ "$layout" == fr ]] && printf jklm || printf hjkl)"
}

case "${1:-}" in
  get) get_layout ;;
  list) printf 'us\nfr\n' ;;
  set)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    apply_layout "$2"
    apply_system_layout "$2"
    ;;
  toggle)
    if [[ "$(get_layout)" == "fr" ]]; then
      apply_layout us
    else
      apply_layout fr
    fi
    apply_system_layout "$(get_layout)"
    ;;
  init)
    apply_layout "${2:-us}"
    apply_system_layout "${2:-us}" sudo
    ;;
  ensure) apply_layout "$(get_layout)" ;;
  *) usage >&2; exit 2 ;;
esac
