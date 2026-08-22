#!/bin/bash
# Verify that everything installed correctly

pass=0
fail=0
OS="$(uname)"

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
if [[ "$OS" == "Darwin" ]]; then
    check "brew"   command -v brew
fi
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
check "atuin"      command -v atuin
check "mise"       command -v mise
check "tofu"       command -v tofu
check "rclone"     command -v rclone
check "psql"       command -v psql
check "nvim"       command -v nvim
check "wget"       command -v wget
check "code"       command -v code
check "docx2txt"   command -v docx2txt.pl

echo ""
echo "Symlinks:"
check_link ".zshrc"            "$HOME/.zshrc"
check_link ".gitconfig"        "$HOME/.gitconfig"
check_link ".gitignore_global" "$HOME/.gitignore_global"
check_link ".gitconfig.local"  "$HOME/.gitconfig.local"
check_link "ssh config"        "$HOME/.ssh/config"
check_link "atuin config"      "$HOME/.config/atuin/config.toml"
check_link "gh config"         "$HOME/.config/gh/config.yml"
check_link "nvim init.lua"     "$HOME/.config/nvim/init.lua"
check_link "nvim lazyvim.json" "$HOME/.config/nvim/lazyvim.json"
check_link "nvim lazy.lua"     "$HOME/.config/nvim/lua/config/lazy.lua"
check_link "nvim claude.lua"   "$HOME/.config/nvim/lua/plugins/claude.lua"

echo ""
echo "Directories:"
check "~/Code"             test -d "$HOME/Code"
check "~/Desktop/screenshots" test -d "$HOME/Desktop/screenshots"

echo ""
echo "Git config:"
check "default branch = main"  test "$(git config init.defaultBranch)" = "main"
check "gpg signing enabled"    test "$(git config commit.gpgsign)" = "true"
check "signing key set"        test "$(git config user.signingkey)" != "ssh-ed25519 CHANGE_ME"

echo ""
echo "Other:"
if [[ "$OS" == "Darwin" ]]; then
    check "1Password SSH agent"      test -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    check ".hushlogin"               test -f "$HOME/.hushlogin"
    check "iTerm2 shell integration" test -f "$HOME/.iterm2_shell_integration.zsh"
    check_link "iTerm2 profile"          "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Default.json"
else
    check "1Password SSH agent"      test -S "$HOME/.1password/agent.sock"
    check "zsh is default shell"     test "$(basename "$SHELL")" = "zsh"
fi

echo ""
echo "Results: $pass passed, $fail failed"
