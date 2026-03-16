#!/bin/bash
# Verify that everything installed correctly

pass=0
fail=0

check() {
    local label="$1"
    shift
    if "$@" &>/dev/null; then
        echo "  ✓ $label"
        ((pass++))
    else
        echo "  ✗ $label"
        ((fail++))
    fi
}

check_link() {
    local label="$1" path="$2"
    if [ -L "$path" ]; then
        echo "  ✓ $label -> $(readlink "$path")"
        ((pass++))
    elif [ -e "$path" ]; then
        echo "  ✗ $label exists but is not a symlink"
        ((fail++))
    else
        echo "  ✗ $label missing"
        ((fail++))
    fi
}

echo "=== Doctor ==="
echo ""

echo "CLI tools:"
check "brew"       command -v brew
check "git"        command -v git
check "node"       command -v node
check "python3"    command -v python3
check "go"         command -v go
check "gh"         command -v gh
check "fzf"        command -v fzf
check "fd"         command -v fd
check "rg"         command -v rg
check "jq"         command -v jq
check "zoxide"     command -v zoxide
check "direnv"     command -v direnv
check "atuin"      command -v atuin
check "terraform"  command -v terraform
check "psql"       command -v psql
check "nvim"       command -v neovim
check "wget"       command -v wget
check "code"       command -v code

echo ""
echo "Symlinks:"
check_link ".zshrc"            "$HOME/.zshrc"
check_link ".gitconfig"        "$HOME/.gitconfig"
check_link ".gitignore_global" "$HOME/.gitignore_global"
check_link "atuin config"      "$HOME/.config/atuin/config.toml"

echo ""
echo "Directories:"
check "~/Code"             test -d "$HOME/Code"
check "~/docs/screenshots" test -d "$HOME/docs/screenshots"

echo ""
echo "Git config:"
check "default branch = main"  test "$(git config init.defaultBranch)" = "main"
check "gpg signing enabled"    test "$(git config commit.gpgsign)" = "true"
check "signing key set"        test "$(git config user.signingkey)" != "ssh-ed25519 CHANGE_ME"

echo ""
echo "Other:"
check "1Password SSH agent"    test -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
check ".hushlogin"             test -f "$HOME/.hushlogin"
check "iTerm2 shell integration" test -f "$HOME/.iterm2_shell_integration.zsh"

echo ""
echo "Results: $pass passed, $fail failed"
