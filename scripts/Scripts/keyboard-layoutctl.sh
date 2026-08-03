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
  write_file "$GENERATED_DIR/rofi.rasi" <<'EOF'
    configuration {
      kb-move-char-back: "Ctrl+j,Left";
      kb-move-char-forward: "Ctrl+m,Right";
      kb-row-down: "Ctrl+k,Down";
      kb-row-up: "Ctrl+l,Up";
    }
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
  write_file "$GENERATED_DIR/rofi.rasi" <<'EOF'
    configuration {
      kb-move-char-back: "Ctrl+h,Left";
      kb-move-char-forward: "Ctrl+l,Right";
      kb-remove-char-back: "BackSpace,Shift+BackSpace";
      kb-row-down: "Ctrl+j,Down";
      kb-row-up: "Ctrl+k,Up";
    }
EOF
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
  set) [[ $# -eq 2 ]] || { usage >&2; exit 2; }; apply_layout "$2" ;;
  toggle)
    if [[ "$(get_layout)" == "fr" ]]; then
      apply_layout us
    else
      apply_layout fr
    fi
    ;;
  init) apply_layout "${2:-us}" ;;
  ensure) apply_layout "$(get_layout)" ;;
  *) usage >&2; exit 2 ;;
esac
