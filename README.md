# dotfiles

Cross-platform setup scripts and configuration files for macOS and Linux.

## Quick Start

```bash
git clone https://github.com/kitsully/dotfiles.git ~/dotfiles
cd ~/dotfiles
./dotfiles.sh
```

`dotfiles.sh` is the one command to remember. It offers the three things you
can do with this repo:

```
    1  Set up this machine   install packages, link configs
    2  Sync back to the repo pick up local changes · 3 uncommitted
    3  Check this machine    verify tools, symlinks, config
    q  Quit
```

Each one also runs on its own if you would rather skip the menu —
`./setup.sh`, `./sync.sh`, `./doctor.sh` — and `./dotfiles.sh setup --work`
passes flags straight through.

Run with no arguments and it walks you through it: it asks whether this is a
work or personal machine, prints the plan, waits for you to confirm, then shows
each step with a progress bar and a summary at the end. Nothing happens until
you say yes.

```
  ? Proceed? [Y]es / [r]eview / [c]ustomize / [q]uit
```

- **`r`** shows what every step will actually do — the packages it would
  install, the files it would link, the macOS settings it would change — and
  then offers to let you tick individual packages off the list.
- **`c`** turns the steps themselves on and off. To see exactly what would happen
without touching anything:

```bash
./setup.sh --dry-run
```

For an unattended run (CI, or a re-run you have already reviewed), `--yes`
accepts every default and asks nothing. It also switches to that mode
automatically when the output is not a terminal.

```bash
./setup.sh --work --yes
```

`setup.sh` auto-detects the platform. You can also pass it explicitly:

```bash
./setup.sh mac
./setup.sh linux
```

On macOS it also takes a **profile**, which selects the app set. The default is
`personal`; a work machine wants `--work`:

```bash
./setup.sh mac            # core + Brewfile.personal
./setup.sh mac --work     # core + Brewfile.work
```

See [Work Mode](#work-mode) for what the work profile leaves out and why.

What it handles per platform:
- **mac**: Xcode CLI tools, Homebrew, Brewfile packages, symlinks, VS Code extensions, FZF, iTerm2, macOS preferences
- **linux**: Distro-native packages (Ubuntu, Fedora, RHEL/CentOS, Arch), standalone tool installs, symlinks, VS Code extensions

### Profiles (macOS)

You are asked which profile to use when you don't pass one:

| Flag | Installs |
|------|----------|
| `--personal` | `Brewfile` + `Brewfile.personal` (default) |
| `--work` | `Brewfile` + `Brewfile.work` |

### Mode Flags

| Flag | Effect |
|------|--------|
| `-y`, `--yes` | Answer every prompt with its default; never asks |
| `-n`, `--dry-run` | Print what each step would do and change nothing |
| `-h`, `--help` | Usage summary |

### Skipping Steps

The interactive `[c]ustomize` option covers most of this, but the `--skip-*`
flags do the same thing non-interactively — useful when a run failed partway
and you want to resume:

```bash
# Skip all heavy installs — run symlinks, VS Code, macOS defaults, doctor, etc.
./setup.sh mac --skip-installs

# Skip only Homebrew + brew bundle, run everything else
./setup.sh mac --skip-brew --skip-packages

# Just re-link dotfiles, nothing else
./setup.sh mac --skip-installs --skip-vscode --skip-fzf --skip-iterm2 --skip-macos-defaults --skip-doctor
```

**macOS flags**

| Flag | What it skips |
|------|--------------|
| `--skip-installs` | Shorthand: skips `--skip-xcode`, `--skip-brew`, `--skip-packages`, `--skip-fzf` |
| `--skip-xcode` | Xcode CLI tools install + license accept |
| `--skip-brew` | Homebrew install |
| `--skip-packages` | `brew bundle` |
| `--skip-fzf` | FZF shell integration |
| `--skip-iterm2` | iTerm2 shell integration download |
| `--skip-macos-defaults` | macOS system preferences (`macos-defaults.sh`) |

**Linux flags**

| Flag | What it skips |
|------|--------------|
| `--skip-installs` | Shorthand: skips `--skip-packages` |
| `--skip-packages` | `linux/packages.sh` + chsh to zsh |

**Both platforms**

| Flag | What it skips |
|------|--------------|
| `--skip-dirs` | Creating `~/Code` and `~/Desktop/screenshots` |
| `--skip-symlinks` | Dotfile symlinking (`install.sh`) |
| `--skip-vscode` | VS Code extension installs |
| `--skip-doctor` | Health check (`doctor.sh`) |

Flags can be combined freely — any step not explicitly skipped will still run.

## Work Mode

`./setup.sh mac --work` installs the core `Brewfile` plus `Brewfile.work`, and
skips `Brewfile.personal` entirely. What it leaves off, and why:

| Left off | Why |
|----------|-----|
| 19 of the 21 Mac App Store apps | Personal purchases that should not follow you onto a corporate device. Note that Drafts and Amphetamine *are* in core, so a work Mac still needs an Apple ID signed in for `mas` to run. |
| Setapp, Soulver, Sublime Text, Sublime Merge | Personal licenses and subscriptions that generally do not cover commercial use. |
| Day One, Evernote, Todoist, Fantastical | Personal notes, journals and calendars — data that should not sync onto a work device. |
| Spotify, GarageBand, iMovie, Flighty, CARROT Weather | Non-work software. |
| Docker Desktop | Requires a **paid business subscription** above a company-size threshold. `Brewfile.work` has commented alternatives (OrbStack, Colima, Podman) — pick whichever your employer licenses. |
| ChatGPT, Claude desktop apps | Check your employer's approved-AI-tools policy first, then add to `Brewfile.work` if permitted. |
| iMazing, SuperDuper | Personal iOS backups and disk cloning; cloning a managed work Mac is usually prohibited. |
| GitHub Desktop | Redundant with the `gh` CLI. |

Everything needed on both machines stays in the core `Brewfile`: the whole CLI
toolchain, fonts, 1Password, iTerm2, VS Code, IntelliJ, Postman, Raycast, Zoom,
the JDK and the browsers, plus Office, Obsidian, Keyboard Maestro, TextExpander,
Hazel, Tower, Transmit, BBEdit, Steam, Drafts and Amphetamine.

To move an app between profiles, just move its line between `Brewfile`,
`Brewfile.personal` and `Brewfile.work` — nothing else references them by name.

### Work Git Identity

> **Required manual step on a work machine.** `./setup.sh --work` cannot do
> this for you — it needs your work email, and the obvious command writes to
> the wrong place.

Work mode does **not** set a work git identity, because there is a trap here:
`~/.gitconfig` and `~/.gitconfig.local` are both symlinks into this repo, so
`git config --global user.email ...` edits tracked files — and this repo is
pushed to GitHub. Set it up with an untracked file instead:

```bash
# 1. Work identity, kept outside the repo so it is never published
cat > ~/.gitconfig.work <<'CONF'
[user]
	email = you@company.com
	signingkey = ~/.ssh/work_signing_key.pub
CONF
```

Then scope it to your work checkouts by adding to `git/.gitconfig`:

```ini
[includeIf "gitdir:~/Code/work/"]
	path = ~/.gitconfig.work
```

Git applies the last matching value, so any repo under `~/Code/work/` uses the
work address while everything else keeps the personal one. The `includeIf`
line itself contains no private data and is safe to commit; `~/.gitconfig.work`
stays untracked. Verify with `git config user.email` inside a work repo.

## Keeping the Repo in Sync

Configs that `install.sh` symlinks — zsh, git, nvim — are edited in place and
show up in `git status` on their own. Three things do **not**, because they live
outside the repo and drift silently: packages you install with `brew`, VS Code
extensions, and the iTerm2 profile.

`sync.sh` reports that drift, then lets you tick off what to fold in. Anything
already in sync starts unchecked, so the default is usually what you want:

```
  ↑↓ or j/k move · space toggles · a all · enter accepts

   ▸ [x] Homebrew packages          9 to add, 3 not installed here
     [x] VS Code extensions         0 added, 1 removed
     [ ] iTerm2 profile             in sync
```

```bash
./sync.sh --dry-run    # just show what changed on this machine
./sync.sh              # show it, then offer to update the files and commit
```

```
Homebrew packages
  ! 9 installed here but not tracked
      + brew "direnv"
      + mas "Xcode", id: 497799835
  ! 3 tracked but not installed here
      - brew "mosh"
```

Notes on how it behaves:

- It compares against `Brewfile` plus **the profile this machine uses**, so
  personal-only apps are not reported as missing on a work Mac. Pass
  `--work`/`--personal` if the guess is wrong.
- Newly installed packages are only ever **added**, and it asks whether they
  belong in the core `Brewfile` or this machine's profile file.
- Things tracked but not installed are **reported and left alone** — on a fresh
  machine that just means you have not installed them yet, not that you want
  them dropped.
- `mas` entries are matched by ID, since the App Store name Homebrew reports
  ("CARROTweather") often differs from the one in the Brewfile ("CARROT Weather").
- Committing is offered at the end; pushing defaults to no.

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | Report only, change nothing |
| `-y`, `--yes` | Take every default, ask nothing |
| `--no-commit` | Update the files but leave them uncommitted |
| `--work` / `--personal` | Which profile this machine uses |

**Adding something to sync.** `sync.sh` has no list of targets in it. It loads
every file in `lib/sync.d/` and takes the name from the filename, so a new
target is a new file defining four functions — `_label`, `_detect`, `_report`
and `_apply`. `lib/sync.d/README.md` has the contract and a skeleton.

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
| `Brewfile` | Core Homebrew formulae, casks and fonts — installed on every Mac |
| `Brewfile.personal` | Personal-only apps, licensed software and Mac App Store apps |
| `Brewfile.work` | Work-machine additions (minimal; container runtime is opt-in) |
| `linux/packages.sh` | Distro-native package install (Ubuntu, Fedora, RHEL, Arch) |
| `dotfiles.sh` | Front door — menu over setup, sync and doctor |
| `setup.sh` | Main bootstrap script (run once on a fresh machine) |
| `sync.sh` | Reports drift in packages, VS Code extensions and the iTerm2 profile, then commits |
| `lib/ui.sh` | Shared colours, prompts, progress bars and the checkbox picker |
| `lib/sync.d/` | One file per thing `sync.sh` can sync — see the README in there to add another |
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
| `config/nvim/` | Neovim config — LazyVim with Claude Code integration; `lazy-lock.json` pins plugin versions so every machine gets the same set |
| `config/gh/config.yml` | GitHub CLI settings and aliases |
| `vscode/extensions.txt` | VS Code extension list (installed by setup.sh) |
| `iterm2/Default.json` | iTerm2 profile, loaded via DynamicProfiles. It appears in iTerm2 as **Dotfiles**, with its own Guid — a dynamic profile must not reuse the Guid of a normal profile, or iTerm2 refuses to load it |

## Linux Distro Support

`setup.sh` auto-detects macOS vs Linux via `uname`. On Linux, `linux/packages.sh` further reads `/etc/os-release` to detect the distro family:

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
~/.config/nvim/lazy-lock.json         → dotfiles/config/nvim/lazy-lock.json
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

**Work machines (required)**
- Set a work git identity — see [Work Git Identity](#work-git-identity).
  Without it, work commits are authored *and signed* with your personal
  address, and `git config --global` writes into this repo rather than
  your machine.
- Sign into 1Password with your work account
- Sign into Raycast with a work account, not your personal cloud sync
