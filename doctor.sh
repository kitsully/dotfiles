#!/bin/bash
# Health check — tells you, in plain language, what is set up and what is not.
#
# Every check knows what it is for, and every failure says what it means
# and how to fix it. Nothing here changes anything on your machine.
#
# Targets bash 3.2 (the macOS system bash).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COLS=66
. "$SCRIPT_DIR/lib/ui.sh"

OS="$(uname)"
PASS=0
NEEDS_N=0
IGNORE_N=0
NEEDS=""
IGNORE=""

# record a problem: list  label  what-it-means  how-to-fix
remember() {
    local entry
    entry="$(printf '    %s·%s %s\n        %s%s%s\n        %sFix: %s%s\n' \
        "$BOLD" "$RESET" "$2" "$DIM" "$3" "$RESET" "$DIM" "$4" "$RESET")"
    # NB: $( ) strips trailing newlines, so add the blank line back here
    if [ "$1" = needs ]; then
        NEEDS="$NEEDS$entry
"; NEEDS_N=$((NEEDS_N+1))
    else
        IGNORE="$IGNORE$entry
"; IGNORE_N=$((IGNORE_N+1))
    fi
}

# check  LABEL  WHAT-IT-IS  WHAT-FAILURE-MEANS  HOW-TO-FIX  --  command...
check() {
    local label="$1" what="$2" why="$3" fix="$4"; shift 5   # drop the --
    if "$@" >/dev/null 2>&1; then
        printf "  %s✓%s %-24s %s%s%s\n" "$GREEN" "$RESET" "$label" "$DIM" "$what" "$RESET"
        PASS=$((PASS+1))
    else
        printf "  %s✗%s %-24s %s%s%s\n" "$RED" "$RESET" "$label" "$DIM" "$what" "$RESET"
        remember needs "$label" "$why" "$fix"
    fi
}

# same, but a failure here is normal and safe to ignore
soft() {
    local label="$1" what="$2" why="$3" fix="$4"; shift 5
    if "$@" >/dev/null 2>&1; then
        printf "  %s✓%s %-24s %s%s%s\n" "$GREEN" "$RESET" "$label" "$DIM" "$what" "$RESET"
        PASS=$((PASS+1))
    else
        printf "  %s~%s %-24s %s%s%s\n" "$YELLOW" "$RESET" "$label" "$DIM" "$what" "$RESET"
        remember ignore "$label" "$why" "$fix"
    fi
}

linked() { [ -L "$1" ]; }

check_link() { # LABEL  WHAT-IT-IS  PATH
    local short="${3/#$HOME/~}"
    if [ -L "$3" ]; then
        printf "  %s✓%s %-24s %s%s%s\n" "$GREEN" "$RESET" "$1" "$DIM" "$2" "$RESET"
        PASS=$((PASS+1))
    elif [ -e "$3" ]; then
        printf "  %s✗%s %-24s %s%s%s\n" "$RED" "$RESET" "$1" "$DIM" "$2" "$RESET"
        remember needs "$1" \
            "There is a real file at $short, so your edits there are not saved in this repo." \
            "Move it aside and run ./install.sh to replace it with a link."
    else
        printf "  %s✗%s %-24s %s%s%s\n" "$RED" "$RESET" "$1" "$DIM" "$2" "$RESET"
        remember needs "$1" \
            "$short does not exist, so this config is not being used at all." \
            "Run ./install.sh"
    fi
}

# psql ships keg-only, so being absent from PATH is expected, not broken
has_psql() { command -v psql >/dev/null 2>&1 || ls /opt/homebrew/opt/postgresql@*/bin/psql >/dev/null 2>&1; }

banner "Health Check" "$([ "$OS" = Darwin ] && echo macOS || echo Linux) · nothing here changes your machine"

printf "\n%sThe programs your shell and editor expect to find%s\n" "$BOLD" "$RESET"
NOT_FOUND="It is not installed, or not on your PATH."
REINSTALL="Run ./setup.sh and let the Packages step finish."
[ "$OS" = Darwin ] && \
check "brew"     "installs everything else"     "$NOT_FOUND" "See https://brew.sh" -- command -v brew
check "git"      "version control"              "$NOT_FOUND" "$REINSTALL" -- command -v git
check "node"     "runs JavaScript"              "$NOT_FOUND" "$REINSTALL" -- command -v node
check "python3"  "runs Python"                  "$NOT_FOUND" "$REINSTALL" -- command -v python3
check "go"       "runs Go"                      "$NOT_FOUND" "$REINSTALL" -- command -v go
check "gh"       "GitHub from the terminal"     "$NOT_FOUND" "$REINSTALL" -- command -v gh
check "fzf"      "fuzzy finder behind ctrl-r"   "$NOT_FOUND" "$REINSTALL" -- command -v fzf
check "fd"       "friendlier find"              "$NOT_FOUND" "$REINSTALL" -- command -v fd
check "rg"       "fast search (ripgrep)"        "$NOT_FOUND" "$REINSTALL" -- command -v rg
check "jq"       "reads JSON"                   "$NOT_FOUND" "$REINSTALL" -- command -v jq
check "zoxide"   "smarter cd"                   "$NOT_FOUND" "$REINSTALL" -- command -v zoxide
check "atuin"    "searchable shell history"     "$NOT_FOUND" "$REINSTALL" -- command -v atuin
check "mise"     "manages language versions"    "$NOT_FOUND" "$REINSTALL" -- command -v mise
check "tofu"     "OpenTofu, builds infra"       "$NOT_FOUND" "$REINSTALL" -- command -v tofu
check "rclone"   "syncs cloud storage"          "$NOT_FOUND" "$REINSTALL" -- command -v rclone
check "nvim"     "Neovim, your editor"          "$NOT_FOUND" "$REINSTALL" -- command -v nvim
check "wget"     "downloads files"              "$NOT_FOUND" "$REINSTALL" -- command -v wget
check "code"     "VS Code from the terminal"    "VS Code is installed but its 'code' command is not on your PATH." \
                 "In VS Code: Cmd+Shift+P, then 'Shell Command: Install code command in PATH'." -- command -v code
check "docx2txt" "reads Word documents"         "$NOT_FOUND" "$REINSTALL" -- command -v docx2txt.pl
soft  "psql"     "PostgreSQL client"            "Postgres is installed, but Homebrew keeps this version off your PATH on purpose so it cannot clash with another Postgres." \
                 "Nothing to do. To use it anyway: /opt/homebrew/opt/postgresql@18/bin/psql" -- has_psql

printf "\n%sYour config files, linked back to this repo%s\n" "$BOLD" "$RESET"
printf "  %sEditing any of these edits the repo, which is the point.%s\n" "$DIM" "$RESET"
check_link ".zshrc"            "your shell setup"            "$HOME/.zshrc"
check_link ".gitconfig"        "your git identity"           "$HOME/.gitconfig"
check_link ".gitignore_global" "files git always ignores"    "$HOME/.gitignore_global"
check_link ".gitconfig.local"  "the Mac/Linux-specific bits" "$HOME/.gitconfig.local"
check_link "ssh config"        "how ssh finds your keys"     "$HOME/.ssh/config"
check_link "atuin config"      "shell history settings"      "$HOME/.config/atuin/config.toml"
check_link "gh config"         "GitHub CLI settings"         "$HOME/.config/gh/config.yml"
check_link "nvim init.lua"     "Neovim entry point"          "$HOME/.config/nvim/init.lua"
check_link "nvim lazyvim.json" "which LazyVim extras load"   "$HOME/.config/nvim/lazyvim.json"
check_link "nvim lazy.lua"     "how plugins are loaded"      "$HOME/.config/nvim/lua/config/lazy.lua"
check_link "nvim claude.lua"   "Claude Code inside Neovim"   "$HOME/.config/nvim/lua/plugins/claude.lua"

printf "\n%sFolders this setup expects%s\n" "$BOLD" "$RESET"
check "~/Code"                "where your projects live"  "The folder is missing." "Run ./setup.sh, or: mkdir -p ~/Code" -- test -d "$HOME/Code"
check "~/Desktop/screenshots" "where screenshots are saved" "The folder is missing, so screenshots have nowhere to go." \
      "Run ./setup.sh, or: mkdir -p ~/Desktop/screenshots" -- test -d "$HOME/Desktop/screenshots"

printf "\n%sGit and commit signing%s\n" "$BOLD" "$RESET"
check "default branch = main" "new repos start on main" "Your git is still creating repos with the old default branch name." \
      "git config --file git/.gitconfig init.defaultBranch main" -- test "$(git config init.defaultBranch)" = "main"
check "signing is on"         "commits are signed"      "Your commits will not be marked verified on GitHub." \
      "Set commit.gpgsign to true in git/.gitconfig" -- test "$(git config commit.gpgsign)" = "true"
check "signing key is set"    "which key signs them"    "No signing key is configured, so signed commits will fail." \
      "Point user.signingkey at your public key, then add it to GitHub as a signing key." \
      -- test -n "$(git config user.signingkey)"

printf "\n%sMac extras%s\n" "$BOLD" "$RESET"
if [ "$OS" = Darwin ]; then
    check "1Password SSH agent" "holds your ssh keys"    "1Password is not serving your SSH keys, so git push and ssh will not authenticate." \
          "Open 1Password > Settings > Developer and turn on 'Use the SSH agent'." \
          -- test -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    soft  ".hushlogin"          "hides the login banner" "Only cosmetic — you will see the 'Last login' line in new terminals." \
          "touch ~/.hushlogin" -- test -f "$HOME/.hushlogin"
    check "iTerm2 integration"  "shell integration script" "iTerm2's extras (marks, command history) will not work." \
          "Run ./setup.sh, or re-run just that step." -- test -f "$HOME/.iterm2_shell_integration.zsh"
    check_link "iTerm2 profile" "your terminal's look" "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Default.json"
else
    check "1Password SSH agent" "holds your ssh keys" "1Password is not serving your SSH keys." \
          "Enable the SSH agent in 1Password's Developer settings." -- test -S "$HOME/.1password/agent.sock"
    check "zsh is your shell"   "the shell this repo configures" "You are still on another shell, so ~/.zshrc is not being read." \
          "chsh -s \$(command -v zsh), then log out and back in." -- test "$(basename "$SHELL")" = "zsh"
fi

# ─── Summary ────────────────────────────────────────────────────────────
TOTAL=$(( PASS + NEEDS_N + IGNORE_N ))
printf "\n"; rule
if [ "$NEEDS_N" -eq 0 ] && [ "$IGNORE_N" -eq 0 ]; then
    printf "  %s%s✓ All %d checks passed. Nothing to do.%s\n" "$BOLD" "$GREEN" "$TOTAL" "$RESET"
elif [ "$NEEDS_N" -eq 0 ]; then
    printf "  %s%s✓ Everything important is fine.%s  %s(%d of %d passed)%s\n" \
           "$BOLD" "$GREEN" "$RESET" "$DIM" "$PASS" "$TOTAL" "$RESET"
else
    printf "  %s%d of %d checks passed.%s\n" "$BOLD" "$PASS" "$TOTAL" "$RESET"
fi
rule

if [ "$NEEDS_N" -gt 0 ]; then
    printf "\n  %s%sWorth fixing (%d)%s\n\n" "$BOLD" "$YELLOW" "$NEEDS_N" "$RESET"
    printf "%s" "$NEEDS"
fi
if [ "$IGNORE_N" -gt 0 ]; then
    printf "\n  %s%sSafe to ignore (%d)%s\n\n" "$BOLD" "$DIM" "$IGNORE_N" "$RESET"
    printf "%s" "$IGNORE"
fi
printf "\n"
