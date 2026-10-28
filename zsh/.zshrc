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

plugins=(git zsh-autosuggestions zsh-syntax-highlighting you-should-use zsh-bat fzf)

source $ZSH/oh-my-zsh.sh

###############
# MY OWN BITS #
###############

source ~/.aliasrc
source ~/.functionrc
source ~/.highlightrc
source ~/.bindingrc

# Your own tweaks in ~/.personalrc, skipped if it doesn't exist
[[ -f ~/.personalrc ]] && source ~/.personalrc

#########
# TOOLS #
#########

# fzf, with a preview of files (bat) and folders (eza)
source <(fzf --zsh)
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --icons=always {} | head -200'"

# fzf, less and yazi move with the Vim keys of the current layout (jklm on AZERTY)
keyboard_state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
keyboard_layout="us"
[[ -r "$keyboard_state_home/hyprpunk/keyboard-layout" ]] &&
  IFS= read -r keyboard_layout <"$keyboard_state_home/hyprpunk/keyboard-layout"
if [[ "$keyboard_layout" != "fr" ]]; then
  export FZF_DEFAULT_OPTS="--bind=ctrl-j:down,ctrl-k:up"
else
  export FZF_DEFAULT_OPTS="--bind=ctrl-k:down,ctrl-l:up"
fi
unset LESSKEY
export LESSKEYIN="$HOME/.local/state/hyprpunk/keyboard/lesskey"
export YAZI_CONFIG_HOME="$HOME/.local/state/hyprpunk/keyboard/yazi"
unset keyboard_layout keyboard_state_home

# z to jump to the folders you visit most
eval "$(zoxide init zsh)"

##########
# PROMPT #
##########

# Starship, set up only once even if this file is sourced again
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
