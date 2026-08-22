#!/bin/bash
set -euo pipefail

# Shared packages across distros (mapped to distro-specific names where needed)
# Covers: Ubuntu/Debian (apt), Fedora (dnf), RHEL/CentOS (dnf), Arch (pacman)
#
# Language runtimes (node, python, go) are deliberately NOT here — mise
# installs them from config/mise/config.toml in the Runtimes setup step.
# python3 stays: it is base-system on these distros and scripts expect it.

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)    echo "debian" ;;
            fedora)           echo "fedora" ;;
            rhel|centos|rocky|alma) echo "rhel" ;;
            arch|manjaro)     echo "arch" ;;
            *)                echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)
echo "Detected distro family: $DISTRO"

install_debian() {
    sudo apt update
    sudo apt install -y \
        zsh \
        git \
        curl \
        wget \
        jq \
        tree \
        neovim \
        fd-find \
        ripgrep \
        fzf \
        python3 \
        cmake \
        graphviz \
        pandoc \
        postgresql-client \
        sqlite3 \
        rclone \
        xclip \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        fontconfig

    # fd is named fdfind on Debian/Ubuntu — create symlink
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
    fi
}

install_fedora() {
    sudo dnf install -y \
        zsh \
        git \
        curl \
        wget \
        jq \
        tree \
        neovim \
        fd-find \
        ripgrep \
        fzf \
        python3 \
        cmake \
        graphviz \
        pandoc \
        postgresql \
        sqlite \
        rclone \
        xclip \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        fontconfig
}

install_rhel() {
    # Enable EPEL for extra packages
    sudo dnf install -y epel-release || true
    sudo dnf install -y \
        zsh \
        git \
        curl \
        wget \
        jq \
        tree \
        neovim \
        fd-find \
        ripgrep \
        fzf \
        python3 \
        cmake \
        graphviz \
        pandoc \
        postgresql \
        sqlite \
        rclone \
        xclip \
        fontconfig

    # zsh plugins may not be in EPEL — install from git if needed
    install_zsh_plugins_from_git
}

install_arch() {
    sudo pacman -Syu --noconfirm \
        zsh \
        git \
        curl \
        wget \
        jq \
        tree \
        neovim \
        fd \
        ripgrep \
        fzf \
        python \
        cmake \
        graphviz \
        pandoc \
        postgresql-libs \
        sqlite \
        rclone \
        xclip \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        fontconfig
}

install_zsh_plugins_from_git() {
    local plugin_dir="$HOME/.zsh/plugins"
    mkdir -p "$plugin_dir"

    if [ ! -d "$plugin_dir/zsh-autosuggestions" ]; then
        echo "Installing zsh-autosuggestions from git..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
    fi

    if [ ! -d "$plugin_dir/zsh-syntax-highlighting" ]; then
        echo "Installing zsh-syntax-highlighting from git..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugin_dir/zsh-syntax-highlighting"
    fi
}

# Tools installed via their own install scripts (not in distro repos)
install_standalone_tools() {
    echo "Installing standalone tools..."

    # mise (runtime manager)
    if ! command -v mise &>/dev/null; then
        echo "Installing mise..."
        curl https://mise.run | sh
    fi

    # atuin (shell history)
    if ! command -v atuin &>/dev/null; then
        echo "Installing atuin..."
        curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
    fi

    # zoxide (smart cd)
    if ! command -v zoxide &>/dev/null; then
        echo "Installing zoxide..."
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi

    # GitHub CLI
    if ! command -v gh &>/dev/null; then
        echo "Installing GitHub CLI..."
        case "$DISTRO" in
            debian)
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                sudo apt update && sudo apt install -y gh
                ;;
            fedora|rhel)
                sudo dnf install -y 'dnf-command(config-manager)'
                sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                sudo dnf install -y gh
                ;;
            arch)
                sudo pacman -S --noconfirm github-cli
                ;;
        esac
    fi

    # Nerd Fonts
    install_nerd_fonts
}

install_nerd_fonts() {
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"

    if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
        echo "Installing JetBrains Mono Nerd Font..."
        curl -fLo /tmp/JetBrainsMono.tar.xz \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
        tar -xf /tmp/JetBrainsMono.tar.xz -C "$font_dir"
        rm /tmp/JetBrainsMono.tar.xz
    fi

    if ! fc-list | grep -qi "MesloLG.*Nerd"; then
        echo "Installing Meslo LG Nerd Font..."
        curl -fLo /tmp/Meslo.tar.xz \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.tar.xz"
        tar -xf /tmp/Meslo.tar.xz -C "$font_dir"
        rm /tmp/Meslo.tar.xz
    fi

    fc-cache -fv "$font_dir"
}

# Main
case "$DISTRO" in
    debian)  install_debian ;;
    fedora)  install_fedora ;;
    rhel)    install_rhel ;;
    arch)    install_arch ;;
    *)
        echo "Unsupported distro. Install packages manually."
        exit 1
        ;;
esac

install_standalone_tools

echo ""
echo "Linux packages installed."
