# === Core ===
export EDITOR="code --wait"
export VISUAL="code --wait"
set -o vi

# === Path ===
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
    export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
fi
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# === Completions ===
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# === Prompt (robbyrussell-style via vcs_info) ===
autoload -Uz vcs_info
setopt PROMPT_SUBST

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr   ' %F{yellow}✗'
zstyle ':vcs_info:git:*' stagedstr     ' %F{yellow}✗'
zstyle ':vcs_info:git:*' formats       ' %F{blue}git:(%F{red}%b%F{blue})%f%u%c'
zstyle ':vcs_info:git:*' actionformats ' %F{blue}git:(%F{red}%b|%a%F{blue})%f%u%c'

precmd() { vcs_info }

PROMPT='%B%(?.%F{green}.%F{red})➜%f%b %B%F{cyan}%c%f%b${vcs_info_msg_0_} '

# === Tool Integrations ===
eval "$(zoxide init zsh)"
eval "$(mise activate zsh)"
eval "$(atuin init zsh)"
eval "$(fzf --zsh)"

# === Zsh Plugins ===
if [[ "$(uname)" == "Darwin" ]]; then
    source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null
    source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" 2>/dev/null
else
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null \
        || source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null \
        || source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
fi

# === 1Password ===
if [[ "$(uname)" == "Darwin" ]]; then
    export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
else
    export SSH_AUTH_SOCK=~/.1password/agent.sock
fi

# === FZF ===
if [[ "$(uname)" == "Darwin" ]]; then
    COPY_CMD="pbcopy"
else
    COPY_CMD="xclip -selection clipboard"
fi
export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window up:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(echo -n {2..} | $COPY_CMD)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"

# === iTerm2 (macOS only) ===
if [[ "$(uname)" == "Darwin" ]]; then
    test -e "$HOME/.iterm2_shell_integration.zsh" && source "$HOME/.iterm2_shell_integration.zsh"
fi

# === ls colors ===
export CLICOLOR=1
if [[ "$(uname)" == "Darwin" ]]; then
    export LSCOLORS="ExGxBxDxCxEgEdxbxgxcxd"
    alias ls="ls -G"
else
    export LS_COLORS="di=1;34:ln=36:so=35:pi=33:ex=32:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"
    alias ls="ls --color=auto"
fi

# === Aliases ===
alias hist="history | fzf"
