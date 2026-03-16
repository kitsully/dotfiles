#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== MacBook Pro Setup ==="

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

# 3. Create directory structure
echo "Creating directories..."
mkdir -p "$HOME/Code"
mkdir -p "$HOME/docs/screenshots"

# 4. Bundle install
echo "Installing packages from Brewfile..."
brew bundle --file="$SCRIPT_DIR/Brewfile"

# 5. Symlink dotfiles
echo "Linking dotfiles..."
bash "$SCRIPT_DIR/install.sh"

# 6. FZF shell integration
echo "Installing FZF shell integration..."
"$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish

# 7. iTerm2 shell integration
if [ ! -f "$HOME/.iterm2_shell_integration.zsh" ]; then
    echo "Downloading iTerm2 shell integration..."
    curl -L https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"
fi

# 8. macOS defaults
echo "Applying macOS preferences..."
bash "$SCRIPT_DIR/macos-defaults.sh"

# 9. Verify installation
echo ""
echo "Running doctor check..."
bash "$SCRIPT_DIR/doctor.sh"

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Manual steps:"
echo "  1. Sign into 1Password and enable SSH agent"
echo "  2. Update signingkey in ~/.gitconfig with your SSH public key"
echo "  3. Sign into iCloud / Mac App Store (required for mas installs)"
echo "  4. Sign into Raycast for cloud sync (restores extensions + config)"
echo "  5. Activate licenses: Alfred, Keyboard Maestro, TextExpander, Setapp"
echo "  6. Import iTerm2 profile from backup"
echo "  7. npm install -g @anthropic-ai/claude-code"
echo "  8. gh extension install github/gh-copilot (optional)"
echo "  9. Restart terminal and verify: source ~/.zshrc"
