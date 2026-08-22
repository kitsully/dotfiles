#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname)"

link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        echo "  backing up $dst -> ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -s "$src" "$dst"
    echo "  $dst -> $src"
}

echo "Creating symlinks..."

link "$DOTFILES/zsh/.zshrc"              "$HOME/.zshrc"
link "$DOTFILES/git/.gitconfig"          "$HOME/.gitconfig"
link "$DOTFILES/git/.gitignore_global"  "$HOME/.gitignore_global"

# Platform-specific git config
if [[ "$OS" == "Darwin" ]]; then
    link "$DOTFILES/git/.gitconfig-macos.local" "$HOME/.gitconfig.local"
else
    link "$DOTFILES/git/.gitconfig-linux.local" "$HOME/.gitconfig.local"
fi

# Platform-specific SSH config
mkdir -p "$HOME/.ssh"
if [[ "$OS" == "Darwin" ]]; then
    link "$DOTFILES/ssh/config.macos"    "$HOME/.ssh/config"
else
    link "$DOTFILES/ssh/config.linux"    "$HOME/.ssh/config"
fi

mkdir -p "$HOME/.config/atuin"
link "$DOTFILES/config/atuin/config.toml" "$HOME/.config/atuin/config.toml"

mkdir -p "$HOME/.config/gh"
link "$DOTFILES/config/gh/config.yml"    "$HOME/.config/gh/config.yml"

mkdir -p "$HOME/.config/nvim/lua/config" "$HOME/.config/nvim/lua/plugins"
link "$DOTFILES/config/nvim/init.lua"            "$HOME/.config/nvim/init.lua"
link "$DOTFILES/config/nvim/lazyvim.json"        "$HOME/.config/nvim/lazyvim.json"
link "$DOTFILES/config/nvim/lazy-lock.json"      "$HOME/.config/nvim/lazy-lock.json"
link "$DOTFILES/config/nvim/stylua.toml"         "$HOME/.config/nvim/stylua.toml"
link "$DOTFILES/config/nvim/.neoconf.json"       "$HOME/.config/nvim/.neoconf.json"
link "$DOTFILES/config/nvim/.gitignore"          "$HOME/.config/nvim/.gitignore"
link "$DOTFILES/config/nvim/lua/config/lazy.lua"     "$HOME/.config/nvim/lua/config/lazy.lua"
link "$DOTFILES/config/nvim/lua/config/keymaps.lua"  "$HOME/.config/nvim/lua/config/keymaps.lua"
link "$DOTFILES/config/nvim/lua/config/autocmds.lua" "$HOME/.config/nvim/lua/config/autocmds.lua"
link "$DOTFILES/config/nvim/lua/config/options.lua"  "$HOME/.config/nvim/lua/config/options.lua"
link "$DOTFILES/config/nvim/lua/plugins/claude.lua"  "$HOME/.config/nvim/lua/plugins/claude.lua"

# iTerm2 profile (macOS only)
if [[ "$OS" == "Darwin" ]]; then
    mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    link "$DOTFILES/iterm2/Default.json" "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Default.json"
fi

echo "Done."
