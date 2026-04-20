# dotfiles

Mac setup scripts and configuration files.

## Quick Start

```bash
git clone https://github.com/kitsully/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```

`setup.sh` handles everything: Xcode CLI tools, Homebrew, packages, dotfile symlinks, VS Code extensions, and macOS preferences.

## What's Inside

| File / Dir | Purpose |
|------------|---------|
| `Brewfile` | Homebrew formulae, casks, fonts, and Mac App Store apps |
| `setup.sh` | Main bootstrap script (run once on a fresh Mac) |
| `install.sh` | Creates symlinks from `~` into this repo |
| `doctor.sh` | Health check — verifies tools, symlinks, and config |
| `macos-defaults.sh` | System preferences (dark mode, dock, keyboard, Finder) |
| `zsh/.zshrc` | Minimal zsh config — no framework, native completions |
| `git/.gitconfig` | Git identity, SSH signing via 1Password |
| `git/.gitignore_global` | Global gitignore |
| `ssh/config` | SSH config (1Password agent) |
| `config/atuin/config.toml` | Atuin shell history settings |
| `config/nvim/` | Neovim config — LazyVim with Claude Code integration |
| `config/gh/config.yml` | GitHub CLI settings and aliases |
| `vscode/extensions.txt` | VS Code extension list (installed by setup.sh) |

## Symlinks

`install.sh` links config files back to this repo so changes are always tracked:

```
~/.zshrc                              → dotfiles/zsh/.zshrc
~/.gitconfig                          → dotfiles/git/.gitconfig
~/.gitignore_global                   → dotfiles/git/.gitignore_global
~/.ssh/config                         → dotfiles/ssh/config
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
- zoxide, direnv, atuin, fzf, mise
- zsh-autosuggestions and zsh-syntax-highlighting
- 1Password SSH agent
- iTerm2 shell integration

## Neovim

LazyVim-based config with extras for: Claude Code AI, Docker, Git, Java, JSON, Python, Rust, SQL, Terraform, TypeScript, YAML. Plugins are bootstrapped automatically on first launch.

## Post-Setup (Manual)

1. Sign into 1Password and enable SSH agent
2. Update signingkey in `~/.gitconfig` with your SSH public key
3. Sign into iCloud / Mac App Store (required for `mas` installs)
4. Sign into Raycast for cloud sync
5. Activate licenses: Keyboard Maestro, TextExpander, Setapp
6. Import iTerm2 profile from backup
7. `npm install -g @anthropic-ai/claude-code`
8. `gh extension install github/gh-copilot` (optional)
