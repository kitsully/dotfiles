#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    echo "Usage: $0 [mac|linux] [flags]"
    echo ""
    echo "Platform is auto-detected if not specified."
    echo ""
    echo "Platforms:"
    echo "  mac     macOS setup"
    echo "  linux   Linux setup"
    echo ""
    echo "Profiles (mac):"
    echo "  --personal             Core + Brewfile.personal (default)"
    echo "  --work                 Core + Brewfile.work — omits personal apps,"
    echo "                         licensed software and all Mac App Store installs"
    echo ""
    echo "Flags (mac):"
    echo "  --skip-installs        Shorthand: skips xcode, brew, packages, fzf"
    echo "  --skip-xcode           Xcode CLI tools + license accept"
    echo "  --skip-brew            Homebrew install"
    echo "  --skip-packages        brew bundle"
    echo "  --skip-fzf             FZF shell integration"
    echo "  --skip-iterm2          iTerm2 shell integration"
    echo "  --skip-macos-defaults  macOS system preferences"
    echo ""
    echo "Flags (linux):"
    echo "  --skip-installs        Shorthand: skips packages"
    echo "  --skip-packages        distro package install + chsh"
    echo ""
    echo "Flags (both):"
    echo "  --skip-dirs            Creating ~/Code and ~/docs/screenshots"
    echo "  --skip-symlinks        Dotfile symlinking"
    echo "  --skip-vscode          VS Code extension installs"
    echo "  --skip-doctor          Health check"
    exit 1
}

# Determine platform — use first arg if it's mac/linux, otherwise auto-detect
if [[ $# -gt 0 && "$1" != --* ]]; then
    PLATFORM="$1"
    shift
    if [[ "$PLATFORM" != "mac" && "$PLATFORM" != "linux" ]]; then
        echo "Error: unknown platform '$PLATFORM'"
        usage
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    PLATFORM="mac"
else
    PLATFORM="linux"
fi

PROFILE=personal

SKIP_XCODE=false
SKIP_BREW=false
SKIP_PACKAGES=false
SKIP_DIRS=false
SKIP_SYMLINKS=false
SKIP_VSCODE=false
SKIP_FZF=false
SKIP_ITERM2=false
SKIP_MACOS_DEFAULTS=false
SKIP_DOCTOR=false

for arg in "$@"; do
    case "$arg" in
        --work)                PROFILE=work ;;
        --personal)            PROFILE=personal ;;
        --skip-installs)
            SKIP_XCODE=true; SKIP_BREW=true; SKIP_PACKAGES=true; SKIP_FZF=true ;;
        --skip-xcode)          SKIP_XCODE=true ;;
        --skip-brew)           SKIP_BREW=true ;;
        --skip-packages)       SKIP_PACKAGES=true ;;
        --skip-dirs)           SKIP_DIRS=true ;;
        --skip-symlinks)       SKIP_SYMLINKS=true ;;
        --skip-vscode)         SKIP_VSCODE=true ;;
        --skip-fzf)            SKIP_FZF=true ;;
        --skip-iterm2)         SKIP_ITERM2=true ;;
        --skip-macos-defaults) SKIP_MACOS_DEFAULTS=true ;;
        --skip-doctor)         SKIP_DOCTOR=true ;;
        *)
            echo "Error: unknown flag '$arg'"
            usage ;;
    esac
done

echo "=== Workstation Setup ($PLATFORM, $PROFILE) ==="

if [[ "$PLATFORM" == "mac" ]]; then
    # 1. Xcode CLI tools + license
    if [[ "$SKIP_XCODE" == false ]]; then
        if ! xcode-select -p &>/dev/null; then
            echo "Installing Xcode Command Line Tools..."
            xcode-select --install
            echo "Press enter after installation completes."
            read -r
        fi

        if xcode-select -p &>/dev/null && ! xcodebuild -checkFirstLaunchStatus &>/dev/null; then
            echo "Accepting Xcode license..."
            sudo xcodebuild -license accept
        fi
    fi

    # 2. Homebrew
    if [[ "$SKIP_BREW" == false ]]; then
        if ! command -v brew &>/dev/null; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi

    # 3. Brewfile packages
    if [[ "$SKIP_PACKAGES" == false ]]; then
        echo "Installing core packages..."
        brew bundle --file="$SCRIPT_DIR/Brewfile"

        PROFILE_BREWFILE="$SCRIPT_DIR/Brewfile.$PROFILE"
        if [ -f "$PROFILE_BREWFILE" ]; then
            echo "Installing $PROFILE packages..."
            brew bundle --file="$PROFILE_BREWFILE"
        fi
    fi

else
    # Linux package install
    if [[ "$SKIP_PACKAGES" == false ]]; then
        echo "Installing Linux packages..."
        bash "$SCRIPT_DIR/linux/packages.sh"

        if [[ "$(basename "$SHELL")" != "zsh" ]]; then
            echo "Setting zsh as default shell..."
            chsh -s "$(which zsh)"
        fi
    fi
fi

# 4. Create directory structure
if [[ "$SKIP_DIRS" == false ]]; then
    echo "Creating directories..."
    mkdir -p "$HOME/Code"
    mkdir -p "$HOME/docs/screenshots"
fi

# 5. Symlink dotfiles
if [[ "$SKIP_SYMLINKS" == false ]]; then
    echo "Linking dotfiles..."
    bash "$SCRIPT_DIR/install.sh"
fi

# 6. VS Code extensions
if [[ "$SKIP_VSCODE" == false ]] && command -v code &>/dev/null; then
    echo "Installing VS Code extensions..."
    while IFS= read -r ext; do
        code --install-extension "$ext" --force 2>/dev/null
    done < "$SCRIPT_DIR/vscode/extensions.txt"
fi

if [[ "$PLATFORM" == "mac" ]]; then
    # 7. FZF shell integration
    if [[ "$SKIP_FZF" == false ]]; then
        echo "Installing FZF shell integration..."
        "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    fi

    # 8. iTerm2 shell integration
    if [[ "$SKIP_ITERM2" == false ]]; then
        if [ ! -f "$HOME/.iterm2_shell_integration.zsh" ]; then
            echo "Downloading iTerm2 shell integration..."
            curl -L https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"
        fi
    fi

    # 9. macOS defaults
    if [[ "$SKIP_MACOS_DEFAULTS" == false ]]; then
        echo "Applying macOS preferences..."
        bash "$SCRIPT_DIR/macos-defaults.sh"
    fi
fi

# 10. Doctor check
if [[ "$SKIP_DOCTOR" == false ]]; then
    echo ""
    echo "Running doctor check..."
    bash "$SCRIPT_DIR/doctor.sh"
fi

echo ""
echo "=== Setup complete! ==="
echo ""

if [[ "$PLATFORM" == "mac" && "$PROFILE" == "work" ]]; then
    echo "Manual steps (work):"
    echo "  1. Sign into 1Password with your WORK account and enable SSH agent"
    echo "  2. Put your signing key at ~/.ssh/git_signing_key.pub"
    echo "  3. Set a work git identity so commits are not authored with your"
    echo "     personal address. Do NOT use 'git config --global' — ~/.gitconfig"
    echo "     is a symlink into this repo. See 'Work Mode' in the README."
    echo "  4. Sign into Raycast with a work account, not your personal sync"
    echo "  5. Import iTerm2 profile from backup"
    echo "  6. npm install -g @anthropic-ai/claude-code"
    echo "  7. Restart terminal and verify: source ~/.zshrc"
    echo ""
    echo "Not installed in work mode: Mac App Store apps (no personal Apple ID"
    echo "needed), personally-licensed software, and Docker Desktop."
    echo "See Brewfile.work to opt in to a container runtime."
elif [[ "$PLATFORM" == "mac" ]]; then
    echo "Manual steps:"
    echo "  1. Sign into 1Password and enable SSH agent"
    echo "  2. Put your signing key at ~/.ssh/git_signing_key.pub"
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
    echo "  2. Put your signing key at ~/.ssh/git_signing_key.pub"
    echo "  3. npm install -g @anthropic-ai/claude-code"
    echo "  4. gh extension install github/gh-copilot (optional)"
    echo "  5. Log out and back in (or restart) for zsh to take effect"
fi
