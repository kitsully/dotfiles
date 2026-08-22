#!/bin/bash
# Health check — says what is set up, what is wrong, and how to fix it.
# Changes nothing; the fix for most failures is re-running ./setup.sh,
# which is safe to repeat.
#
# To add a check, add one line in the right section below:
#   check "label"  "what failure means"  "how to fix it"  -- command
# The command's exit status is the verdict; the -- is required.
# soft() is the same, for failures that are safe to ignore.
#
# Package checks come from the Brewfiles and symlink checks from
# `install.sh --list`, so those two need no editing here.
#
# Targets bash 3.2 (the macOS system bash).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname)"
TAB="$(printf '\t')"

case "${1:-}" in
    "") ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *)  printf "unknown flag '%s' — doctor only reports; ./setup.sh fixes\n" "$1"; exit 1 ;;
esac

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi

PASS=0; NEEDS_N=0; SOFT_N=0; NEEDS=""; SOFTS=""

detail() { # label why fix
    printf '    %s·%s %s\n        %s%s%s\n        %sFix: %s%s\n' \
        "$BOLD" "$RESET" "$1" "$DIM" "$2" "$RESET" "$DIM" "$3" "$RESET"
}
pass_line() { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; PASS=$((PASS+1)); }
fail_line() { # label why fix
    printf "  %s✗%s %s\n" "$RED" "$RESET" "$1"
    NEEDS="$NEEDS$(detail "$1" "$2" "$3")
"; NEEDS_N=$((NEEDS_N+1))
}
check() { local label="$1" why="$2" fix="$3"; shift 4
    if "$@" >/dev/null 2>&1; then pass_line "$label"; else fail_line "$label" "$why" "$fix"; fi
}
soft() { local label="$1" why="$2" fix="$3"; shift 4
    if "$@" >/dev/null 2>&1; then pass_line "$label"; return; fi
    printf "  %s~%s %s\n" "$YELLOW" "$RESET" "$label"
    SOFTS="$SOFTS$(detail "$label" "$why" "$fix")
"; SOFT_N=$((SOFT_N+1))
}

check_bundle() { # label  brewfile — a failure names exactly what is missing
    local label="$1" file="$2" out list missing
    # NO_UPGRADE: report only what is missing, not what is merely outdated
    if out="$(HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle check --verbose --file="$file" 2>&1)"; then
        pass_line "$label"; return 0
    fi
    list="$(printf '%s\n' "$out" \
        | sed -n 's/^→ \(.*\) needs to be.*$/\1/p' \
        | sed 's/^Formula /brew /; s/^Cask /cask /; s/^App /mas /')"
    missing="$(printf '%s\n' "$list" | awk 'NR>1 { printf ", " } { printf "%s", $0 } END { print "" }')"
    # only App Store apps missing is expected until the machine is signed in
    # (and forever on a VM, which cannot sign in) — safe to ignore, not broken
    if [ -n "$list" ] && [ "$(printf '%s\n' "$list" | grep -cv '^mas ')" -eq 0 ]; then
        soft "$label" "Only App Store apps are missing: $missing" \
            "Sign into the App Store, then run ./setup.sh." -- false
        return 0
    fi
    [ -z "$missing" ] && missing="brew bundle check failed: $(printf '%s' "$out" | head -1)"
    fail_line "$label" "Not installed here: $missing" "Run ./setup.sh — brew bundle installs what is missing."
}

PROFILE=""
[ -f "$HOME/.config/dotfiles/profile" ] && PROFILE="$(cat "$HOME/.config/dotfiles/profile")"

printf "\n%s┌─ dotfiles doctor%s\n" "$BOLD" "$RESET"
printf "%s│%s  %sreport only — ./setup.sh fixes%s\n" "$BOLD" "$RESET" "$DIM" "$RESET"
printf "%s└─%s\n" "$BOLD" "$RESET"

# ── Packages ────────────────────────────────────────────────────────────
# Checked straight against the Brewfiles: add a package there, it is
# checked here automatically.
printf "\n%sPackages%s\n" "$BOLD" "$RESET"
if [ "$OS" = Darwin ]; then
    check "Homebrew" "brew is not installed, so nothing else can be." \
        "See https://brew.sh, or run ./setup.sh" -- command -v brew
    check "profile recorded" "sync.sh and doctor.sh cannot know which Brewfile.<name> this machine uses." \
        "Run ./setup.sh <profile> once." -- test -n "$PROFILE"
    if command -v brew >/dev/null 2>&1; then
        check_bundle "core packages (Brewfile)" "$SCRIPT_DIR/Brewfile"
        [ -n "$PROFILE" ] && check_bundle "$PROFILE packages (Brewfile.$PROFILE)" "$SCRIPT_DIR/Brewfile.$PROFILE"
    fi
fi
check_mise() { # runtimes come from config/mise/config.toml — nothing to edit here
    command -v mise >/dev/null 2>&1 || { fail_line "runtimes (mise)" "mise is not installed, so no language runtimes are managed." "Run ./setup.sh"; return 0; }
    local out missing
    # stderr stays out of the list: mise prints harmless warnings there
    if ! out="$(mise ls --missing 2>/dev/null)"; then
        fail_line "runtimes (mise)" "mise itself errored: $(mise ls --missing 2>&1 >/dev/null | head -1)" \
            "Fix mise first (brew reinstall mise), then re-run ./setup.sh."
        return 0
    fi
    if [ -z "$out" ]; then pass_line "runtimes (mise)"; return 0; fi
    missing="$(printf '%s\n' "$out" | awk 'NR>1 { printf ", " } { printf "%s %s", $1, $2 }')"
    fail_line "runtimes (mise)" "Not installed here: $missing" "Run ./setup.sh — it runs 'mise install'."
}
check_mise
check "code on PATH" "VS Code's terminal command is missing, so extensions cannot be installed or synced." \
    "In VS Code: Cmd+Shift+P, then 'Shell Command: Install code command in PATH'." -- command -v code

# ── Symlinks ────────────────────────────────────────────────────────────
# The list comes from `install.sh --list` — nothing to maintain here.
printf "\n%sConfig symlinks%s  %s(editing these edits the repo — that is the point)%s\n" "$BOLD" "$RESET" "$DIM" "$RESET"
while IFS="$TAB" read -r src dst; do
    short="${dst/#$HOME/\~}"
    if [ -L "$dst" ]; then
        pass_line "$short"
    elif [ -e "$dst" ]; then
        fail_line "$short" "A real file sits there, so edits to it are not tracked in this repo." \
            "Run ./install.sh — it backs the file up and links the repo copy."
    else
        fail_line "$short" "Nothing is there, so this config is not in use at all." \
            "Run ./install.sh"
    fi
done < <(bash "$SCRIPT_DIR/install.sh" --list)

# ── Folders ─────────────────────────────────────────────────────────────
printf "\n%sFolders%s\n" "$BOLD" "$RESET"
check "~/Code" "The projects folder is missing." "Run ./setup.sh, or: mkdir -p ~/Code" -- test -d "$HOME/Code"
check "~/Desktop/screenshots" "Screenshots have nowhere to go." \
    "Run ./setup.sh, or: mkdir -p ~/Desktop/screenshots" -- test -d "$HOME/Desktop/screenshots"

# ── Git ─────────────────────────────────────────────────────────────────
printf "\n%sGit and commit signing%s\n" "$BOLD" "$RESET"
check "default branch = main" "New repos would still start on the old default branch name." \
    "git config --file git/.gitconfig init.defaultBranch main" -- test "$(git config init.defaultBranch)" = "main"
check "signing is on" "Commits will not be marked verified on GitHub." \
    "Set commit.gpgsign to true in git/.gitconfig" -- test "$(git config commit.gpgsign)" = "true"
check "signing key is set" "No signing key is configured, so signed commits will fail." \
    "Point user.signingkey at your public key, then add it to GitHub as a signing key." \
    -- test -n "$(git config user.signingkey)"
SIGNING_KEY="$(git config user.signingkey)"
check "signing key file exists" "user.signingkey points at a file that is not on this machine, so the first commit will fail." \
    "Save the public key there — see Post-Setup step 3 in README.md." \
    -- test -f "${SIGNING_KEY/#\~/$HOME}"

# ── Platform extras ─────────────────────────────────────────────────────
printf "\n%s%s extras%s\n" "$BOLD" "$([ "$OS" = Darwin ] && echo Mac || echo Linux)" "$RESET"
if [ "$OS" = Darwin ]; then
    check "1Password SSH agent" "1Password is not serving your SSH keys, so git push and ssh will not authenticate." \
        "Open 1Password > Settings > Developer and turn on 'Use the SSH agent'." \
        -- test -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    check "iTerm2 integration" "iTerm2's extras (marks, command history) will not work." \
        "Run ./setup.sh" -- test -f "$HOME/.iterm2_shell_integration.zsh"
    soft "Touch ID for sudo" "sudo asks for a typed password instead of a fingerprint." \
        "Run ./setup.sh — the macOS preferences step sets it up." \
        -- grep -q '^auth' /etc/pam.d/sudo_local
    soft ".hushlogin" "Only cosmetic — new terminals show the 'Last login' line." \
        "touch ~/.hushlogin" -- test -f "$HOME/.hushlogin"
else
    check "1Password SSH agent" "1Password is not serving your SSH keys." \
        "Enable the SSH agent in 1Password's Developer settings." -- test -S "$HOME/.1password/agent.sock"
    check "zsh is your shell" "You are on another shell, so ~/.zshrc is not being read." \
        "chsh -s \$(command -v zsh), then log out and back in." -- test "$(basename "$SHELL")" = "zsh"
fi

# ── Summary ─────────────────────────────────────────────────────────────
TOTAL=$((PASS + NEEDS_N + SOFT_N))
printf "\n"
if [ "$NEEDS_N" -eq 0 ] && [ "$SOFT_N" -eq 0 ]; then
    printf "  %s%s✓ All %d checks passed. Nothing to do.%s\n" "$BOLD" "$GREEN" "$TOTAL" "$RESET"
elif [ "$NEEDS_N" -eq 0 ]; then
    printf "  %s%s✓ Everything important is fine.%s  %s(%d of %d passed)%s\n" \
        "$BOLD" "$GREEN" "$RESET" "$DIM" "$PASS" "$TOTAL" "$RESET"
else
    printf "  %s%d of %d checks passed.%s\n" "$BOLD" "$PASS" "$TOTAL" "$RESET"
fi
if [ "$NEEDS_N" -gt 0 ]; then
    printf "\n  %s%sWorth fixing (%d)%s\n\n%s" "$BOLD" "$YELLOW" "$NEEDS_N" "$RESET" "$NEEDS"
fi
if [ "$SOFT_N" -gt 0 ]; then
    printf "\n  %s%sSafe to ignore (%d)%s\n\n%s" "$BOLD" "$DIM" "$SOFT_N" "$RESET" "$SOFTS"
fi
printf "\n"
[ "$NEEDS_N" -eq 0 ]
