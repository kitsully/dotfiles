# dotfiles

One person's machine setup: the config files, the Brewfiles, and a small set
of scripts that install, link, sync and check them. macOS and Linux.

## Quick start

On a brand-new Mac, straight out of the box (nothing to install first — the
`git clone` itself triggers the Command Line Tools dialog; click Install,
wait, then run the clone again; https needs no ssh keys, which come later):

```bash
git clone https://github.com/kitsully/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh <profile>     # e.g. ./setup.sh personal — see Profiles below
```

Three scripts, no menus, no prompts:

| Script | Does | When |
|--------|------|------|
| `./setup.sh` | Installs everything: Xcode CLI tools, Homebrew, macOS preferences (early, so Touch ID covers the sudo prompts that follow), packages, symlinks, VS Code extensions, fzf + iTerm2 integration, then a health check. Add `--upgrade` to also update already-installed packages, `--dock` to also apply the Dock layout (off by default — it replaces the current Dock). | Fresh machine — and re-run any time to pick up new packages and configs. |
| `./sync.sh` | Folds this machine's drift back into the repo: brew packages, VS Code extensions, the iTerm2 profile. Shows each target's drift and asks before writing (`--yes` skips the asking); then shows `git status` — you review and commit. | Occasionally, at the keyboard. |
| `./doctor.sh` | Says what is wrong and how to fix it. Changes nothing. | When in doubt. |

Everything is safe to re-run. `--dry-run` works on `setup.sh` and `sync.sh`.
`./install.sh` (just the symlinks) is run by setup but also works alone.

## Profiles

A profile names a kind of machine and picks its app set: the core `Brewfile`
(every Mac) plus `Brewfile.<profile>` (that kind only). **Any
`Brewfile.<name>` file in the repo is a valid profile** — a new kind of
machine means creating one file and running `./setup.sh <name>`. Nothing else
knows the profile names.

The first `./setup.sh <profile>` records the choice in
`~/.config/dotfiles/profile`; from then on `setup.sh`, `sync.sh` and
`doctor.sh` all read it, so they never guess. Re-run setup with a different
name to change it.

## How do I…

Each of these is also answered by a comment in the file you would edit.

- **Add or remove a package** — edit `Brewfile` (every Mac) or
  `Brewfile.<profile>` (that kind of machine only), then re-run `./setup.sh`.
  Removing a line stops tracking it; nothing is uninstalled for you.
- **Add a new kind of machine** — create `Brewfile.<name>`, run
  `./setup.sh <name>`.
- **Skip a step for one run** — comment out its `step` line at the bottom of
  `setup.sh`.
- **Change the Dock** — edit `dock/<profile>.txt` (one app path per line,
  top-to-bottom is left-to-right), then `./setup.sh --dock`. Without the
  flag the Dock is never touched — the step replaces the whole layout, so
  it is opt-in.
- **Add a config file** — put it under `config/`; `install.sh` links
  everything in there to the same path under `~/.config` automatically.
  Dotfiles that live directly in `~` get one `link` line in `install.sh`.
- **Change a language runtime version** — edit `config/mise/config.toml`
  (node, python, go live there, not in the Brewfiles), then re-run
  `./setup.sh`. A project can override with its own `.mise.toml`.
- **Make a machine match the config exactly** — removing what the repo does
  not track is deliberately not sync's job (sync only adds). Brew does it:
  `cat Brewfile Brewfile.<profile> | brew bundle cleanup --file=- --force`.
  It uninstalls App Store apps and taps too, so run it without `--force`
  first and read the list.
- **Add a health check** — one `check` line in `doctor.sh` (the header shows
  the shape). Package and symlink checks are derived, so those never need
  editing.
- **Add a sync target** — a `sync_<thing>()` function in `sync.sh`, called in
  the list at the bottom (the header shows the shape).

## What's inside

| Path | Purpose |
|------|---------|
| `Brewfile`, `Brewfile.personal`, `Brewfile.work` | Package sets: core + one file per kind of machine |
| `setup.sh` | Install/update everything (the only script with an argument: the profile) |
| `install.sh` | Symlinks configs into `$HOME`, backing up real files; `--list` prints the mapping |
| `sync.sh` | Folds brew/VS Code/iTerm2 drift back into the repo |
| `doctor.sh` | Health check, report-only |
| `macos-defaults.sh` | macOS system preferences (dock, keyboard, Finder…) |
| `dock/<profile>.txt` | Dock layout per profile: one app path per line, in order; `setup.sh --dock` applies it with `dockutil` (opt-in) |
| `linux/packages.sh` | Distro-native packages: Ubuntu/Debian, Fedora, RHEL, Arch |
| `zsh/`, `git/`, `ssh/`, `config/`, `iterm2/`, `vscode/` | The actual configs |

Notes on two of the configs:

- `iterm2/Default.json` is a *dynamic* profile (shown in iTerm2 as
  **Dotfiles**) with its own Guid — iTerm2 refuses a dynamic profile that
  reuses a real profile's Guid. `sync.sh` compares settings semantically.
- `vscode/extensions.txt` is exactly `code --list-extensions`; setup installs
  from it, sync rewrites it. `vscode/settings.json` is symlinked into VS
  Code's User folder, so edits in VS Code's settings UI land in the repo.
- `config/mise/config.toml` pins the global language runtimes (node, python,
  go) — mise makes `python`/`node`/`go` work at any prompt, and a directory
  with its own `.mise.toml` overrides them. Brew stays for CLI tools and
  apps; runtimes deliberately live here instead so `brew upgrade` can never
  jump a language version underneath you.

## Work git identity

> **Required manual step on a work machine.** Setup cannot do this for you —
> it needs your work email, and the obvious command writes to the wrong place.

`~/.gitconfig` and `~/.gitconfig.local` are symlinks into this repo, so
`git config --global user.email ...` would edit tracked files that get pushed
to GitHub. Use an untracked file instead:

```bash
# Work identity, kept outside the repo so it is never published
cat > ~/.gitconfig.work <<'CONF'
[user]
	email = you@company.com
	signingkey = ~/.ssh/work_signing_key.pub
CONF
```

Then scope it to your work checkouts by adding to `git/.gitconfig` (this line
holds no private data and is safe to commit):

```ini
[includeIf "gitdir:~/Code/work/"]
	path = ~/.gitconfig.work
```

Any repo under `~/Code/work/` now uses the work identity; everything else
keeps the personal one. Verify with `git config user.email` inside a work repo.

## Post-Setup

The manual follow-ups `setup.sh` cannot do:

**Every machine**
1. Sign into 1Password and enable Settings → Developer → "Use the SSH agent".
2. Store or import your SSH key in 1Password; add the public key to GitHub as
   both an **authentication** and a **signing** key.
3. Check the tracked public key still matches the agent's (`ssh-add -L` vs
   `ssh/git_signing_key.pub` — install.sh links it to
   `~/.ssh/git_signing_key.pub`, so signing works as soon as 1Password is
   signed in; only a *new* key means updating the repo copy).
4. Install Claude Code: `curl -fsSL https://claude.ai/install.sh | bash` (the standalone installer keeps itself updated)
5. Test: `ssh -T git@github.com`, then `git commit --allow-empty -m test`.

**Personal Macs**
- Sign into iCloud / the Mac App Store (the `mas` installs need it).
- Sign into Raycast for cloud sync.
- Licenses: Keyboard Maestro, TextExpander, Setapp.

**Work Macs**
- Set the work git identity (above) — without it, commits are authored *and
  signed* with your personal address.
- 1Password and Raycast: sign in with **work** accounts, not personal sync.
- The Mac App Store still needs an Apple ID (Drafts and Amphetamine are in
  the core Brewfile via `mas`).
- Licenses: TextExpander, Hazel, Tower, Transmit, BBEdit.
- Docker Desktop is intentionally not in `Brewfile.work` (paid business
  subscription); commented alternatives (OrbStack, Colima, Podman) are in
  that file.

**Linux**
- Log out and back in so zsh takes effect.

## Linux

`setup.sh` detects the platform with `uname`; on Linux it runs
`linux/packages.sh`, which reads `/etc/os-release` and uses `apt`
(Ubuntu/Debian), `dnf` (Fedora/RHEL) or `pacman` (Arch). Tools not in distro
repos (mise, atuin, zoxide, gh) install via their official scripts. Profiles
are a Mac concept; Linux machines share one package list.
