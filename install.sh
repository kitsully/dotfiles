#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

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

mkdir -p "$HOME/.ssh"
link "$DOTFILES/ssh/config"              "$HOME/.ssh/config"

mkdir -p "$HOME/.config/atuin"
link "$DOTFILES/config/atuin/config.toml" "$HOME/.config/atuin/config.toml"

mkdir -p "$HOME/.config/gh"
link "$DOTFILES/config/gh/config.yml"    "$HOME/.config/gh/config.yml"

mkdir -p "$HOME/.config/nvim/lua/config" "$HOME/.config/nvim/lua/plugins"
link "$DOTFILES/config/nvim/init.lua"            "$HOME/.config/nvim/init.lua"
link "$DOTFILES/config/nvim/lazyvim.json"        "$HOME/.config/nvim/lazyvim.json"
link "$DOTFILES/config/nvim/stylua.toml"         "$HOME/.config/nvim/stylua.toml"
link "$DOTFILES/config/nvim/.neoconf.json"       "$HOME/.config/nvim/.neoconf.json"
link "$DOTFILES/config/nvim/.gitignore"          "$HOME/.config/nvim/.gitignore"
link "$DOTFILES/config/nvim/lua/config/lazy.lua"     "$HOME/.config/nvim/lua/config/lazy.lua"
link "$DOTFILES/config/nvim/lua/config/keymaps.lua"  "$HOME/.config/nvim/lua/config/keymaps.lua"
link "$DOTFILES/config/nvim/lua/config/autocmds.lua" "$HOME/.config/nvim/lua/config/autocmds.lua"
link "$DOTFILES/config/nvim/lua/config/options.lua"  "$HOME/.config/nvim/lua/config/options.lua"
link "$DOTFILES/config/nvim/lua/plugins/claude.lua"  "$HOME/.config/nvim/lua/plugins/claude.lua"

echo "Done."
