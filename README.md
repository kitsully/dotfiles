# dotfiles

Cross-platform setup scripts and configuration files for macOS and Linux.

## Quick Start

```bash
git clone https://github.com/kitsully/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```

`setup.sh` detects the platform and handles everything automatically:
- **macOS**: Xcode CLI tools, Homebrew, Brewfile packages, symlinks, VS Code extensions, macOS preferences
- **Linux**: Distro-native packages (Ubuntu, Fedora, RHEL/CentOS, Arch), standalone tool installs, symlinks, VS Code extensions

## Updating an Existing Machine

After making changes on one machine, pull them down on another:

```bash
cd ~/dotfiles
git pull
./install.sh            # re-links all configs (safe to run repeatedly)
```

If the Brewfile or packages changed, also sync packages:

```bash
# macOS
brew bundle --file=~/dotfiles/Brewfile

# Linux
./linux/packages.sh
```

To verify everything is in order:

```bash
./doctor.sh
```

## What's Inside

| File / Dir | Purpose |
|------------|---------|
| `Brewfile` | Homebrew formulae, casks, fonts, and Mac App Store apps (macOS) |
| `linux/packages.sh` | Distro-native package install (Ubuntu, Fedora, RHEL, Arch) |
| `setup.sh` | Main bootstrap script (run once on a fresh machine) |
| `install.sh` | Creates symlinks — platform-aware for git and SSH configs |
| `doctor.sh` | Health check — verifies tools, symlinks, and config |
| `macos-defaults.sh` | macOS system preferences (dark mode, dock, keyboard, Finder) |
| `zsh/.zshrc` | Zsh config — no framework, platform-aware paths and integrations |
| `git/.gitconfig` | Git identity, SSH signing, aliases |
| `git/.gitconfig-macos.local` | macOS-specific git config (1Password signing, osxkeychain) |
| `git/.gitconfig-linux.local` | Linux-specific git config (1Password signing, credential store) |
| `git/.gitignore_global` | Global gitignore |
| `ssh/config.macos` | SSH config for macOS (1Password agent) |
| `ssh/config.linux` | SSH config for Linux (1Password agent) |
| `config/atuin/config.toml` | Atuin shell history settings |
| `config/nvim/` | Neovim config — LazyVim with Claude Code integration |
| `config/gh/config.yml` | GitHub CLI settings and aliases |
| `vscode/extensions.txt` | VS Code extension list (installed by setup.sh) |
| `iterm2/Default.json` | iTerm2 profile (loaded via DynamicProfiles on macOS) |

## Platform Detection

Scripts use `uname` to detect macOS vs Linux. On Linux, `linux/packages.sh` reads `/etc/os-release` to detect the distro family:

| Distro | Package Manager |
|--------|----------------|
| Ubuntu / Debian | `apt` |
| Fedora | `dnf` |
| RHEL / CentOS / Rocky / Alma | `dnf` + EPEL |
| Arch / Manjaro | `pacman` |

Tools not available in distro repos (mise, atuin, zoxide, gh) are installed via their official install scripts.

## Symlinks

`install.sh` links config files back to this repo. Platform-specific files (git, SSH) are selected automatically:

```
~/.zshrc                              → dotfiles/zsh/.zshrc
~/.gitconfig                          → dotfiles/git/.gitconfig
~/.gitconfig.local                    → dotfiles/git/.gitconfig-{macos,linux}.local
~/.gitignore_global                   → dotfiles/git/.gitignore_global
~/.ssh/config                         → dotfiles/ssh/config.{macos,linux}
~/.config/atuin/config.toml           → dotfiles/config/atuin/config.toml
~/.config/gh/config.yml               → dotfiles/config/gh/config.yml
~/.config/nvim/init.lua               → dotfiles/config/nvim/init.lua
~/.config/nvim/lazyvim.json           → dotfiles/config/nvim/lazyvim.json
~/.config/nvim/lua/config/*.lua       → dotfiles/config/nvim/lua/config/*.lua
~/.config/nvim/lua/plugins/claude.lua → dotfiles/config/nvim/lua/plugins/claude.lua
```

Existing files are backed up to `*.bak` before linking.

## Shell Setup

The `.zshrc` uses no frameworks (no Oh My Zsh). It sets up:

- vi mode
- Native zsh completions and git-branch prompt via `vcs_info`
- zoxide, mise, atuin, fzf
- zsh-autosuggestions and zsh-syntax-highlighting
- 1Password SSH agent (platform-aware paths)
- iTerm2 shell integration (macOS only)

## Neovim

LazyVim-based config with extras for: Claude Code AI, Docker, Git, Java, JSON, Python, Rust, SQL, Terraform, TypeScript, YAML. Plugins are bootstrapped automatically on first launch.

## Post-Setup (Manual)

### 1. 1Password + SSH Keys

The dotfiles are configured to use 1Password's SSH agent for both SSH auth *and* Git commit signing. After installing 1Password:

1. **Sign into 1Password** and unlock the vault
2. **Enable the SSH agent**:
   - macOS: 1Password > Settings > Developer > "Use the SSH agent"
   - Linux: 1Password > Settings > Developer > "Use the SSH agent" (also enable "Integrate with 1Password CLI" if using `op`)
3. **Store your SSH key in 1Password** (if not already there):
   - Create a new item of type "SSH Key"
   - Either generate a new ed25519 key, or import an existing one
   - The public key is available in the item's details
4. **Verify the signing key in `git/.gitconfig`** matches your 1Password SSH key:
   ```bash
   # Show the public key currently being offered by the agent:
   ssh-add -L
   # Compare with what's set in the repo:
   grep signingkey ~/dotfiles/git/.gitconfig
   ```
   If they don't match, edit `git/.gitconfig` and commit the update.
5. **Add the public key to GitHub** (and any other Git hosts):
   - GitHub > Settings > SSH and GPG keys
   - Add it as both an **Authentication key** (for SSH) and a **Signing key** (for verified commits)
6. **Test it**:
   ```bash
   ssh -T git@github.com              # should greet you by username
   git commit --allow-empty -m test   # should succeed without prompting
   ```

### 2. Other Manual Steps

**macOS**
- Sign into iCloud / Mac App Store (required for `mas` installs)
- Sign into Raycast for cloud sync
- Activate licenses: Keyboard Maestro, TextExpander, Setapp
- `npm install -g @anthropic-ai/claude-code`

**Linux**
- `npm install -g @anthropic-ai/claude-code`
- Log out and back in for zsh to take effect
