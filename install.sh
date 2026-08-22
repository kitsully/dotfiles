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

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
    BOLD=""; DIM=""; GREEN=""; YELLOW=""; RESET=""
fi

LINKED=0; BACKED=0
link() {
    local src="$1" dst="$2"
    if [ "$LIST_ONLY" = true ]; then printf '%s\t%s\n' "$src" "$dst"; return 0; fi
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then
        # replace our own links freely, but a symlink into somewhere else
        # (oh-my-zsh, another dotfiles tool) is backed up like a real file
        case "$(readlink "$dst")" in
            "$DOTFILES"/*) rm "$dst" ;;
            *) local bak="$dst.bak"
               [ -e "$bak" ] || [ -L "$bak" ] && bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
               printf "  %s↷ backed up %s → %s%s\n" "$YELLOW" "~${dst#"$HOME"}" "~${bak#"$HOME"}" "$RESET"
               mv "$dst" "$bak"; BACKED=$((BACKED+1)) ;;
        esac
    elif [ -e "$dst" ]; then
        local bak="$dst.bak"
        [ -e "$bak" ] && bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
        # not ${dst/#$HOME/\~}: bash 3.2 keeps the backslash and prints '\~'
        printf "  %s↷ backed up %s → %s%s\n" "$YELLOW" "~${dst#"$HOME"}" "~${bak#"$HOME"}" "$RESET"
        mv "$dst" "$bak"; BACKED=$((BACKED+1))
    fi
    ln -s "$src" "$dst"
    printf "  %s✓%s %-52s %s→ %s%s\n" "$GREEN" "$RESET" "~${dst#"$HOME"}" "$DIM" "${src#"$DOTFILES"/}" "$RESET"
    LINKED=$((LINKED+1))
}

# ssh refuses configs in a directory other users can touch — create it tight
if [ "$LIST_ONLY" = false ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
fi

# ── Dotfiles linked straight into ~ — add or remove a line here ──────────
link "$DOTFILES/zsh/.zshrc"             "$HOME/.zshrc"
link "$DOTFILES/git/.gitconfig"         "$HOME/.gitconfig"
link "$DOTFILES/git/.gitignore_global"  "$HOME/.gitignore_global"
link "$DOTFILES/claude/settings.json"   "$HOME/.claude/settings.json"
# public key material only — the private keys live in 1Password, never here
link "$DOTFILES/ssh/allowed_signers"      "$HOME/.ssh/allowed_signers"
link "$DOTFILES/ssh/git_signing_key.pub"  "$HOME/.ssh/git_signing_key.pub"

if [ "$OS" = Darwin ]; then
    link "$DOTFILES/git/.gitconfig-macos.local" "$HOME/.gitconfig.local"
    link "$DOTFILES/ssh/config.macos"           "$HOME/.ssh/config"
    link "$DOTFILES/iterm2/Default.json" "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Default.json"
    link "$DOTFILES/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
else
    link "$DOTFILES/git/.gitconfig-linux.local" "$HOME/.gitconfig.local"
    link "$DOTFILES/ssh/config.linux"           "$HOME/.ssh/config"
    link "$DOTFILES/vscode/settings.json"       "$HOME/.config/Code/User/settings.json"
fi

# ── Everything under config/ mirrors into ~/.config/ — nothing to edit ───
while IFS= read -r f; do
    link "$f" "$HOME/.config/${f#"$DOTFILES"/config/}"
done < <(find "$DOTFILES/config" -type f | sort)

if [ "$LIST_ONLY" = false ]; then
    if [ "$BACKED" -gt 0 ]; then
        printf "%s✓ %d links in place%s %s(%d existing files backed up — remove the .bak copies once you trust the links)%s\n" \
            "$GREEN" "$LINKED" "$RESET" "$DIM" "$BACKED" "$RESET"
    else
        printf "%s✓ %d links in place%s\n" "$GREEN" "$LINKED" "$RESET"
    fi
fi
