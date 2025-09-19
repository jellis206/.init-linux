# Powerlevel10k instant prompt (keep near the top)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
source "$HOME/.p10k.zsh"

# Core plugins; add your own later
plugins=(git fzf docker zsh-autosuggestions zsh-completions zsh-history-substring-search zsh-syntax-highlighting)

autoload -Uz compinit && compinit
source "$ZSH/oh-my-zsh.sh"

# Third-party plugins (installed under $ZSH_CUSTOM)
[[ -f "$ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# asdf modern setup: PATH shims first; add completions to fpath
path=(
  $HOME/go/bin
  $HOME/.cargo/bin
  $ASDF_DATA_DIR/shims
  $HOME/.local/bin
  /usr/local/bin
  /usr/bin
  /bin
  /usr/sbin
  /sbin
)
# Deduplicate & validate
typeset -U path
export PATH

# zoxide (smarter cd)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Editor
export VISUAL=nvim
export EDITOR=nvim

# History & shell behavior
export HISTSIZE=2000
export SAVEHIST=2000
export HISTFILE="$HOME/.zsh_history"
setopt SHARE_HISTORY AUTO_CD NO_CASE_GLOB HIST_IGNORE_DUPS COMPLETE_ALIASES

# Your custom files (optional)
setopt null_glob
for file in $HOME/.env-vars/*.{zsh,sh}; do [ -r "$file" ] && source "$file"; done
for file in $HOME/.sh-functions/*.{zsh,sh}; do [ -r "$file" ] && source "$file"; done
for file in $HOME/.sh-aliases/*.{zsh,sh}; do [ -r "$file" ] && source "$file"; done
unsetopt null_glob

# remove duplicate entries in PATH
export PATH=$(echo "$PATH" | awk -v RS=':' '{
    # First normalize any multiple slashes to single slashes
    gsub("//+","/")
    # Then do the deduplication check
    if (!($0 in a)) {
        a[$0]
        printf("%s%s", sep, $0)
        sep=":"
    }
}')
