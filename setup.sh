#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname)"

echo "=== Workstation Setup ==="

if [[ "$OS" == "Darwin" ]]; then
    # 1. Xcode CLI tools
    if ! xcode-select -p &>/dev/null; then
        echo "Installing Xcode Command Line Tools..."
        xcode-select --install
        echo "Press enter after installation completes."
        read -r
    fi

    # 2. Homebrew
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # 3. Accept Xcode license if needed
    if xcode-select -p &>/dev/null && ! xcodebuild -checkFirstLaunchStatus &>/dev/null; then
        echo "Accepting Xcode license..."
        sudo xcodebuild -license accept
    fi

    # 4. Bundle install
    echo "Installing packages from Brewfile..."
    brew bundle --file="$SCRIPT_DIR/Brewfile"
else
    # Linux package install
    echo "Installing Linux packages..."
    bash "$SCRIPT_DIR/linux/packages.sh"

    # Set zsh as default shell if it isn't already
    if [[ "$(basename "$SHELL")" != "zsh" ]]; then
        echo "Setting zsh as default shell..."
        chsh -s "$(which zsh)"
    fi
fi

# 4. Create directory structure
echo "Creating directories..."
mkdir -p "$HOME/Code"
mkdir -p "$HOME/docs/screenshots"

# 5. Symlink dotfiles
echo "Linking dotfiles..."
bash "$SCRIPT_DIR/install.sh"

# 6. VS Code extensions
if command -v code &>/dev/null; then
    echo "Installing VS Code extensions..."
    while IFS= read -r ext; do
        code --install-extension "$ext" --force 2>/dev/null
    done < "$SCRIPT_DIR/vscode/extensions.txt"
fi

# 7. FZF shell integration
if [[ "$OS" == "Darwin" ]]; then
    echo "Installing FZF shell integration..."
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
fi

# 8. iTerm2 shell integration (macOS only)
if [[ "$OS" == "Darwin" ]]; then
    if [ ! -f "$HOME/.iterm2_shell_integration.zsh" ]; then
        echo "Downloading iTerm2 shell integration..."
        curl -L https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"
    fi
fi

# 9. macOS defaults
if [[ "$OS" == "Darwin" ]]; then
    echo "Applying macOS preferences..."
    bash "$SCRIPT_DIR/macos-defaults.sh"
fi

# 10. Verify installation
echo ""
echo "Running doctor check..."
bash "$SCRIPT_DIR/doctor.sh"

echo ""
echo "=== Setup complete! ==="
echo ""

if [[ "$OS" == "Darwin" ]]; then
    echo "Manual steps:"
    echo "  1. Sign into 1Password and enable SSH agent"
    echo "  2. Update signingkey in ~/.gitconfig with your SSH public key"
    echo "  3. Sign into iCloud / Mac App Store (required for mas installs)"
    echo "  4. Sign into Raycast for cloud sync (restores extensions + config)"
    echo "  5. Activate licenses: Keyboard Maestro, TextExpander, Setapp"
    echo "  6. Import iTerm2 profile from backup"
    echo "  7. npm install -g @anthropic-ai/claude-code"
    echo "  8. gh extension install github/gh-copilot (optional)"
    echo "  9. Restart terminal and verify: source ~/.zshrc"
else
    echo "Manual steps:"
    echo "  1. Install and configure 1Password with SSH agent"
    echo "  2. Update signingkey in ~/.gitconfig with your SSH public key"
    echo "  3. npm install -g @anthropic-ai/claude-code"
    echo "  4. gh extension install github/gh-copilot (optional)"
    echo "  5. Log out and back in (or restart) for zsh to take effect"
fi
