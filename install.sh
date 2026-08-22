#!/bin/bash
# Symlinks configs into $HOME. Run by setup.sh; safe to run alone, repeatedly.
#
# To add a config file: put it anywhere under config/ and re-run — everything
# in config/ is linked to the same path under ~/.config, no list to edit.
# Dotfiles that live directly in ~ get one `link` line below.
#
# Existing real files are backed up to .bak; an older backup is never
# overwritten (a timestamped name is used instead).
#
# `install.sh --list` prints the src<TAB>dst pairs without changing anything —
# doctor.sh uses it, so the link list lives only here.

set -euo pipefail
set -o errtrace   # the ERR trap must fire inside link() too
trap 'echo "install.sh stopped on an error — fix the cause above and re-run; links already made are fine." >&2' ERR

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname)"
LIST_ONLY=false
[ "${1:-}" = "--list" ] && LIST_ONLY=true

link() {
    local src="$1" dst="$2"
    if [ "$LIST_ONLY" = true ]; then printf '%s\t%s\n' "$src" "$dst"; return 0; fi
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        local bak="$dst.bak"
        [ -e "$bak" ] && bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
        echo "  backing up $dst -> $bak"
        mv "$dst" "$bak"
    fi
    ln -s "$src" "$dst"
    echo "  $dst -> $src"
}

# ── Dotfiles linked straight into ~ — add or remove a line here ──────────
link "$DOTFILES/zsh/.zshrc"             "$HOME/.zshrc"
link "$DOTFILES/git/.gitconfig"         "$HOME/.gitconfig"
link "$DOTFILES/git/.gitignore_global"  "$HOME/.gitignore_global"
link "$DOTFILES/claude/settings.json"   "$HOME/.claude/settings.json"

if [ "$OS" = Darwin ]; then
    link "$DOTFILES/git/.gitconfig-macos.local" "$HOME/.gitconfig.local"
    link "$DOTFILES/ssh/config.macos"           "$HOME/.ssh/config"
    link "$DOTFILES/iterm2/Default.json" "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Default.json"
else
    link "$DOTFILES/git/.gitconfig-linux.local" "$HOME/.gitconfig.local"
    link "$DOTFILES/ssh/config.linux"           "$HOME/.ssh/config"
fi

# ── Everything under config/ mirrors into ~/.config/ — nothing to edit ───
find "$DOTFILES/config" -type f | sort | while IFS= read -r f; do
    link "$f" "$HOME/.config/${f#"$DOTFILES"/config/}"
done

[ "$LIST_ONLY" = true ] || echo "Done."
