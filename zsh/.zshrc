# FASTFETCH
if [[ -z "$TMUX" ]]; then
  command -v fastfetch >/dev/null 2>&1 && fastfetch
fi

# OPTIONAL (if you don't need a ~/.completionrc file you can remove this line)
[[ -f ~/.completionrc ]] && source ~/.completionrc

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME=""

# Plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting you-should-use zsh-bat fzf)

# Source oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Sources
source ~/.aliasrc
source ~/.functionrc
source ~/.highlightrc
source ~/.bindingrc

# OPTIONAL (if you don't need a ~/.personalrc file you can remove this line)
[[ -f ~/.personalrc ]] && source ~/.personalrc

# FZF config
source <(fzf --zsh)
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --icons=always {} | head -200'"
keyboard_state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
keyboard_layout="us"
[[ -r "$keyboard_state_home/hyprpunk/keyboard-layout" ]] &&
  IFS= read -r keyboard_layout <"$keyboard_state_home/hyprpunk/keyboard-layout"
if [[ "$keyboard_layout" != "fr" ]]; then
  export FZF_DEFAULT_OPTS="--bind=ctrl-j:down,ctrl-k:up"
else
  export FZF_DEFAULT_OPTS="--bind=ctrl-k:down,ctrl-l:up"
fi
export LESSKEY="$HOME/.local/state/hyprpunk/keyboard/lesskey"
export YAZI_CONFIG_HOME="$HOME/.local/state/hyprpunk/keyboard/yazi"
unset keyboard_layout keyboard_state_home

# ZOXIDE config
eval "$(zoxide init zsh)"

# STARSHIP init
type starship_zle-keymap-select >/dev/null || \
  {
    eval "$(starship init zsh)"
  }

# STARSHIP transient prompt
autoload -Uz add-zle-hook-widget

_transient_prompt() {
  PROMPT='$(starship prompt --profile transient --terminal-width=$COLUMNS --keymap=${KEYMAP:-})'
  RPROMPT=''
  zle reset-prompt
}

_restore_prompt() {
  PROMPT='$(starship prompt --terminal-width=$COLUMNS --keymap=${KEYMAP:-})'
  RPROMPT='$(starship prompt --right --terminal-width=$COLUMNS --keymap=${KEYMAP:-})'
  zle reset-prompt
}

add-zle-hook-widget zle-line-finish _transient_prompt
add-zle-hook-widget line-init _restore_prompt
