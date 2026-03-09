# STARSHIP init
eval "$(starship init zsh)"

# # FASTFETCH
if [[ -z "$TMUX" ]]; then
  command -v fastfetch >/dev/null 2>&1 && fastfetch
fi


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
[[ -f ~/.personalrc ]] && source ~/.personalrc

# FZF config
source <(fzf --zsh)
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --icons=always {} | head -200'"
export FZF_DEFAULT_OPTS="--bind=ctrl-k:down,ctrl-l:up"

# ZOXIDE config
eval "$(zoxide init zsh)"
