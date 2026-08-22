#!/bin/bash
# Sets up this machine — and updates it. Re-run any time to pick up new
# packages and configs; every step is safe to repeat.
#
#   ./setup.sh <profile>     first run: pick the app set. Any Brewfile.<name>
#                            in this repo is a valid profile, so a new kind of
#                            machine is just a new Brewfile.<name> — no code.
#   ./setup.sh               later runs reuse the profile recorded in
#                            ~/.config/dotfiles/profile
#   ./setup.sh --upgrade     also upgrade already-installed packages to their
#                            latest versions (default is install-missing only)
#   ./setup.sh --dock        also apply the Dock layout from dock/<profile>.txt
#                            (replaces the current Dock, so it is opt-in)
#   ./setup.sh --dry-run     show what would run, change nothing
#
# To skip a step for one run, comment out its `step` line at the bottom.
# Manual follow-ups (sign-ins, licenses) are in README.md under "Post-Setup".
#
# Targets bash 3.2 (the macOS system bash). Works without a TTY, and never
# does anything destructive because nobody was there to answer a prompt.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE_FILE="$HOME/.config/dotfiles/profile"
[ "$(uname)" = Darwin ] && PLATFORM=mac || PLATFORM=linux
[ -t 0 ] || export NONINTERACTIVE=1   # tells the Homebrew installer not to prompt

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi
ok()   { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
info() { printf "  %s%s%s\n" "$DIM" "$1" "$RESET"; }
run()  { if [ "$DRY_RUN" = true ]; then info "would run: $*"; return 0; fi; "$@"; }

profiles() { ls "$SCRIPT_DIR"/Brewfile.* 2>/dev/null | sed 's/.*Brewfile\./  /'; }

# ── Arguments: [profile] [--upgrade] [--dry-run] ────────────────────────
DRY_RUN=false
UPGRADE=false
DOCK=false
PROFILE=""
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=true ;;
        --upgrade)    UPGRADE=true ;;
        --dock)       DOCK=true ;;
        -h|--help)    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
        -*)           printf "unknown flag '%s' — try --help\n" "$arg"; exit 1 ;;
        *)            PROFILE="$arg" ;;
    esac
done

if [ "$PLATFORM" = mac ]; then
    [ -z "$PROFILE" ] && [ -f "$PROFILE_FILE" ] && PROFILE="$(cat "$PROFILE_FILE")"
    if [ -z "$PROFILE" ]; then
        printf "%sNo profile recorded on this machine yet.%s Run:\n\n    ./setup.sh <profile>\n\nwhere <profile> is any of the Brewfile.<name> files here:\n%s\n" \
            "$BOLD" "$RESET" "$(profiles)"
        exit 1
    fi
    if [ ! -f "$SCRIPT_DIR/Brewfile.$PROFILE" ]; then
        printf "%sThere is no Brewfile.%s in this repo.%s Existing profiles:\n%s\n\nA new kind of machine just needs a new Brewfile.<name> file.\n" \
            "$BOLD" "$PROFILE" "$RESET" "$(profiles)"
        exit 1
    fi
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "${PROFILE_FILE%/*}"
        printf '%s\n' "$PROFILE" > "$PROFILE_FILE"   # sync.sh and doctor.sh read this
    fi
fi

# Ask for sudo once, up front, and keep it warm for the whole run — casks,
# the Xcode license, and the macOS preferences all need it, and each would
# otherwise prompt for your password again.
if [ "$PLATFORM" = mac ] && [ "$DRY_RUN" = false ] && [ -t 0 ]; then
    sudo -v
    ( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
fi

# ── Steps ───────────────────────────────────────────────────────────────
do_xcode() {
    xcode-select -p >/dev/null 2>&1 && { ok "already installed"; return 0; }
    if [ "$DRY_RUN" = true ]; then info "would run: xcode-select --install"; return 0; fi
    info "a system dialog will open — click Install; waiting until it finishes"
    xcode-select --install 2>/dev/null
    # bounded: if the dialog was cancelled (or never appeared), fail the step
    # instead of spinning here forever
    local waited=0
    until xcode-select -p >/dev/null 2>&1; do
        [ "$waited" -ge 1800 ] && { warn "not installed after 30 minutes — dialog cancelled? re-run ./setup.sh"; return 1; }
        sleep 10; waited=$((waited+10))
    done
    if command -v xcodebuild >/dev/null 2>&1 && ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
        info "accepting the Xcode license (needs your password)"
        sudo xcodebuild -license accept || return 1
    fi
}

do_brew() {
    # a fresh shell may not have brew on PATH even when it is installed
    if ! command -v brew >/dev/null 2>&1 && [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    command -v brew >/dev/null 2>&1 && { ok "already installed"; return 0; }
    if [ "$DRY_RUN" = true ]; then info "would install Homebrew"; return 0; fi
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
    eval "$(/opt/homebrew/bin/brew shellenv)"
}

do_packages() {
    if [ "$PLATFORM" = linux ]; then
        run bash "$SCRIPT_DIR/linux/packages.sh" || return 1
        if [ "$(basename "$SHELL")" != zsh ] && [ "$DRY_RUN" = false ]; then
            chsh -s "$(command -v zsh)" || warn "could not set zsh as login shell — run chsh yourself"
        fi
        return 0
    fi
    # --verbose streams each package's progress; without it, brew's parallel
    # fetch phase sits silent for minutes on a big install
    local bundle_flags="--verbose"
    if [ "$UPGRADE" = false ]; then
        bundle_flags="$bundle_flags --no-upgrade"
        info "installing missing packages only — pass --upgrade to also update installed ones"
    fi
    run brew bundle $bundle_flags --file="$SCRIPT_DIR/Brewfile" || return 1
    run brew bundle $bundle_flags --file="$SCRIPT_DIR/Brewfile.$PROFILE" || return 1
}

do_dirs() { run mkdir -p "$HOME/Code" "$HOME/Desktop/screenshots"; }

do_symlinks() { run bash "$SCRIPT_DIR/install.sh"; }

# language runtimes (node, python, go) come from config/mise/config.toml,
# which the symlinks step just linked — edit that file to change versions
do_runtimes() {
    command -v mise >/dev/null 2>&1 || { warn "mise not installed — skipping"; return 0; }
    run mise install
}

do_vscode() {
    command -v code >/dev/null 2>&1 || { warn "'code' not on PATH — skipping"; return 0; }
    local n=0 ext
    while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        n=$((n+1))
        info "$ext"
        [ "$DRY_RUN" = true ] || code --install-extension "$ext" --force >/dev/null 2>&1
    done < "$SCRIPT_DIR/vscode/extensions.txt"
    if [ "$DRY_RUN" = true ]; then info "would install $n extensions from vscode/extensions.txt"
    else ok "$n extensions"; fi
}

do_fzf() {
    command -v brew >/dev/null 2>&1 || { info "needs Homebrew — skipping"; return 0; }
    if [ "$DRY_RUN" = true ]; then info "would run fzf's installer"; return 0; fi
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish >/dev/null || return 1
    ok "key bindings and completion"
}

do_iterm2() {
    # always refreshed, so updates to the script are picked up on re-runs
    if [ "$DRY_RUN" = true ]; then info "would refresh ~/.iterm2_shell_integration.zsh"; return 0; fi
    local tmp="$HOME/.iterm2_shell_integration.zsh.new"
    if curl -fsSL https://iterm2.com/shell_integration/zsh -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$HOME/.iterm2_shell_integration.zsh"
        ok "downloaded"
    else
        rm -f "$tmp"
        warn "could not download (offline?) — keeping the existing copy"
        [ -f "$HOME/.iterm2_shell_integration.zsh" ] || return 1
    fi
}

do_macos_defaults() { run bash "$SCRIPT_DIR/macos-defaults.sh"; }

# Dock layout is declarative: dock/<profile>.txt lists the apps in order,
# and the Dock is set to exactly that list. Edit the file to change it.
do_dock() {
    local list="$SCRIPT_DIR/dock/$PROFILE.txt"
    [ "$DOCK" = false ] && { info "off by default (replaces the current Dock) — pass --dock to apply dock/$PROFILE.txt"; return 0; }
    [ -f "$list" ] || { info "no dock/$PROFILE.txt in the repo — skipping"; return 0; }
    command -v dockutil >/dev/null 2>&1 || { warn "dockutil not installed (it is in the Brewfile) — skipping"; return 0; }
    if [ "$DRY_RUN" = true ]; then info "would set the Dock from dock/$PROFILE.txt"; return 0; fi
    dockutil --remove all --no-restart >/dev/null 2>&1
    local app missing=""
    while IFS= read -r app; do
        case "$app" in ''|\#*) continue ;; esac
        if [ -e "$app" ]; then
            dockutil --add "$app" --no-restart >/dev/null 2>&1 || warn "could not add ${app##*/}"
        else
            missing="$missing${app##*/}, "
        fi
    done < "$list"
    killall Dock 2>/dev/null
    [ -n "$missing" ] && info "not installed yet, left out: ${missing%, } — re-run setup once installed"
    ok "Dock set from dock/$PROFILE.txt"
}

# findings here (a missing sign-in, say) are not a setup failure — always 0
do_doctor() { run bash "$SCRIPT_DIR/doctor.sh"; return 0; }

# ── Run ─────────────────────────────────────────────────────────────────
FAILED=""
step() {
    printf "\n%s▸ %s%s\n" "$BOLD" "$1" "$RESET"
    "$2" || { FAILED="$FAILED$1, "; printf "  %s✗ %s failed — continuing%s\n" "$RED" "$1" "$RESET"; }
}

# To skip a step for one run, comment out its line.
if [ "$PLATFORM" = mac ]; then
    step "Xcode Command Line Tools"        do_xcode
    step "Homebrew"                        do_brew
    step "Packages (core + $PROFILE)"      do_packages
    step "Directories"                     do_dirs
    step "Dotfile symlinks"                do_symlinks
    step "Runtimes (mise)"                 do_runtimes
    step "VS Code extensions"              do_vscode
    step "fzf shell integration"           do_fzf
    step "iTerm2 shell integration"        do_iterm2
    step "macOS preferences"               do_macos_defaults
    step "Dock layout"                     do_dock
    step "Health check"                    do_doctor
else
    step "Packages"                        do_packages
    step "Directories"                     do_dirs
    step "Dotfile symlinks"                do_symlinks
    step "Runtimes (mise)"                 do_runtimes
    step "VS Code extensions"              do_vscode
    step "Health check"                    do_doctor
fi

# ── Summary ─────────────────────────────────────────────────────────────
printf "\n"
if [ -n "$FAILED" ]; then
    printf "%s%s✗ Failed:%s %s\n" "$BOLD" "$RED" "$RESET" "${FAILED%, }"
    info "each error is printed above, at the end of its '▸ <step>' section"
    info "fix the cause and re-run ./setup.sh — finished steps repeat harmlessly"
    exit 1
fi
if [ "$DRY_RUN" = true ]; then info "dry run — nothing was changed"; exit 0; fi
ok "Done. Manual follow-ups (sign-ins, licenses): see Post-Setup in README.md."
