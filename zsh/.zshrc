# Everything a new terminal's zsh loads. Your own bits go in ~/.personalrc and
# ~/.completionrc, so git pull never clashes with them.

# A little hello in every new terminal, but not in each tmux pane
if [[ -z "$TMUX" ]]; then
  command -v fastfetch >/dev/null 2>&1 && fastfetch
fi

# Your own completions in ~/.completionrc, skipped if it doesn't exist
[[ -f ~/.completionrc ]] && source ~/.completionrc

#############
# OH MY ZSH #
#############

export ZSH="$HOME/.oh-my-zsh"

# No theme, Starship draws the prompt
ZSH_THEME=""

plugins=(git zsh-autosuggestions zsh-syntax-highlighting you-should-use zsh-bat)

source $ZSH/oh-my-zsh.sh

#######################
# HYPRPUNK'S OWN BITS #
#######################

# The keyboard layout picked in the shell, read once for .bindingrc's Vim keys and the
# tools below
hyprpunk_state="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk"
keyboard_layout="us"
[[ -r "$hyprpunk_state/keyboard-layout" ]] &&
  IFS= read -r keyboard_layout <"$hyprpunk_state/keyboard-layout"

source ~/.aliasrc
source ~/.functionrc
source ~/.highlightrc
source ~/.bindingrc

#########
# TOOLS #
#########

# fzf, with a preview of files (bat) and folders (eza)
source <(fzf --zsh)
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --icons=always {} | head -200'"

# fzf, less and yazi move with the Vim keys of the current layout (jklm on AZERTY)
if [[ "$keyboard_layout" != "fr" ]]; then
  export FZF_DEFAULT_OPTS="--bind=ctrl-j:down,ctrl-k:up"
else
  export FZF_DEFAULT_OPTS="--bind=ctrl-k:down,ctrl-l:up"
fi
unset LESSKEY
export LESSKEYIN="$hyprpunk_state/keyboard/lesskey"
export YAZI_CONFIG_HOME="$hyprpunk_state/keyboard/yazi"
unset keyboard_layout hyprpunk_state

# z to jump to the folders you visit most
eval "$(zoxide init zsh)"

##########
# PROMPT #
##########

# Starship, in the wallpaper's palette written by matugen, set up only once even if this
# file is sourced again
export STARSHIP_CONFIG="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk/starship.toml"
type starship_zle-keymap-select >/dev/null || \
  {
    eval "$(starship init zsh)"
  }

# Transient prompt: once a command is sent, its prompt shrinks to keep the history tidy
autoload -Uz add-zle-hook-widget

# kitty finds your prompt by a mark it slips into it. Swapping the prompt drops that mark,
# and kitty then thinks a command is still running and asks before closing the window
_prompt_mark() {
  (( ${+functions[_ksi_precmd]} )) && PROMPT=$'%{\e]133;A\a%}'$PROMPT
}

_transient_prompt() {
  PROMPT='$(starship prompt --profile transient --terminal-width=$COLUMNS --keymap=${KEYMAP:-})'
  RPROMPT=''
  _prompt_mark
  zle reset-prompt
}

_restore_prompt() {
  PROMPT='$(starship prompt --terminal-width=$COLUMNS --keymap=${KEYMAP:-})'
  RPROMPT='$(starship prompt --right --terminal-width=$COLUMNS --keymap=${KEYMAP:-})'
  _prompt_mark
  zle reset-prompt
}

add-zle-hook-widget zle-line-finish _transient_prompt
add-zle-hook-widget line-init _restore_prompt

# A new palette sends SIGURG to every zsh, so the prompt you're typing at is drawn again
# in its colors. Every other program ignores it.
TRAPURG() {
  zle && zle reset-prompt
}

#################
# YOUR OWN BITS #
#################

# Your own tweaks in ~/.personalrc, skipped if it doesn't exist. Read last, so they
# win over anything above, fzf's options and the prompt included.
[[ -f ~/.personalrc ]] && source ~/.personalrc
