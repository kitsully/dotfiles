# dotfiles

Mac setup scripts and configuration files.

## Quick Start

```bash
git clone https://github.com/kitsully/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```

`setup.sh` handles everything: Xcode CLI tools, Homebrew, packages, dotfile symlinks, and macOS preferences.

## What's Inside

| File | Purpose |
|------|---------|
| `Brewfile` | Homebrew formulae, casks, and Mac App Store apps |
| `setup.sh` | Main bootstrap script (run once on a fresh Mac) |
| `install.sh` | Creates symlinks from `~` into this repo |
| `macos-defaults.sh` | System preferences (dark mode, dock, keyboard, Finder) |
| `zsh/.zshrc` | Minimal zsh config — no framework, native completions |
| `git/.gitconfig` | Git identity |
| `config/atuin/config.toml` | Atuin shell history settings |

## Symlinks

`install.sh` links config files back to this repo so changes are always tracked:

```
~/.zshrc                    → dotfiles/zsh/.zshrc
~/.gitconfig                → dotfiles/git/.gitconfig
~/.config/atuin/config.toml → dotfiles/config/atuin/config.toml
```

Existing files are backed up to `*.bak` before linking.

## Shell Setup

The `.zshrc` uses no frameworks (no Oh My Zsh). It sets up:

- vi mode
- Native zsh completions and git-branch prompt via `vcs_info`
- zoxide, direnv, atuin, fzf
- 1Password SSH agent
- iTerm2 shell integration

## Post-Setup (Manual)

1. Sign into 1Password and enable SSH agent
2. Sign into iCloud / Mac App Store
3. Sign into Raycast for cloud sync
4. Activate licenses: Alfred, Keyboard Maestro, TextExpander, Setapp
5. Import iTerm2 profile
6. `npm install -g @anthropic-ai/claude-code`
