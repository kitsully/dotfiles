#!/bin/bash
# Sets up this machine — and updates it. Re-run any time to pick up new
# packages and configs; every step is safe to repeat.
#
#   ./setup.sh <profile>     first run: pick the app set. Any Brewfile.<name>
#                            in this repo is a valid profile, so a new kind of
#                            machine is just a new Brewfile.<name> — no code.
#                            (Run without one at a terminal and it asks.)
#   ./setup.sh               later runs reuse the profile recorded in
#                            ~/.config/dotfiles/profile
#   ./setup.sh --upgrade     also upgrade already-installed packages to their
#                            latest versions (default is install-missing only)
#   ./setup.sh --dock        also apply the Dock layout from dock/<profile>.txt
#                            (replaces the current Dock, so it is opt-in)
#   ./setup.sh --headless    Linux: this machine gets no desktop (GUI) apps
#   ./setup.sh --desktop     Linux: install desktop apps from linux/apps*.txt
#                            (with neither flag, the first run asks — or, off
#                            a terminal, goes by whether a display is present —
#                            and records the answer in ~/.config/dotfiles)
#   ./setup.sh --dry-run     show what would run, change nothing
#
# To skip a step for one run, comment out its `step` line at the bottom.
# Manual follow-ups (sign-ins, licenses) are in README.md under "Post-Setup".
#
# On a Mac it asks for your password once, then answers the sudo prompts
# from cask pkg installers itself (they ignore sudo's cache on purpose);
# the held copy is overwritten and deleted when the run ends.
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
HEADLESS=""
PROFILE=""
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=true ;;
        --upgrade)    UPGRADE=true ;;
        --dock)       DOCK=true ;;
        --headless)   HEADLESS=yes ;;
        --desktop)    HEADLESS=no ;;
        -h|--help)    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
        -*)           printf "unknown flag '%s' — try --help\n" "$arg"; exit 1 ;;
        *)            PROFILE="$arg" ;;
    esac
done

# Profiles apply on both platforms: Brewfile.<name> defines the namespace,
# and on Linux the same name also picks linux/apps.<name>.txt. First run at
# a terminal asks; off a terminal it still needs the argument.
[ -z "$PROFILE" ] && [ -f "$PROFILE_FILE" ] && PROFILE="$(cat "$PROFILE_FILE")"
if [ -z "$PROFILE" ] && [ -t 0 ]; then
    printf "%sNo profile recorded on this machine yet.%s A profile names a kind of\nmachine — one per Brewfile.<name> file here:\n%s\n" \
        "$BOLD" "$RESET" "$(profiles)"
    while [ -z "$PROFILE" ]; do
        printf "Profile for this machine: "
        IFS= read -r PROFILE || { printf "\n"; exit 1; }
        if [ -n "$PROFILE" ] && [ ! -f "$SCRIPT_DIR/Brewfile.$PROFILE" ]; then
            printf "There is no Brewfile.%s in this repo — pick one of:\n%s\n" "$PROFILE" "$(profiles)"
            PROFILE=""
        fi
    done
fi
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

# Headless is a Linux-only axis: a server gets everything except the desktop
# (Flatpak) apps. Decided once — flag beats the recorded answer beats a
# prompt whose default comes from whether a display is present (off a
# terminal the default just applies) — then remembered for later runs.
HEADLESS_FILE="$HOME/.config/dotfiles/headless"
if [ "$PLATFORM" = linux ]; then
    if [ -z "$HEADLESS" ] && [ -f "$HEADLESS_FILE" ]; then
        HEADLESS="$(cat "$HEADLESS_FILE")"
        case "$HEADLESS" in yes|no) ;; *) HEADLESS="" ;; esac
    fi
    if [ -z "$HEADLESS" ]; then
        [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && guess=no || guess=yes
        if [ -t 0 ]; then
            [ "$guess" = yes ] && hint="Y/n" || hint="y/N"
            printf "Is this machine headless — no desktop apps like Firefox? [%s] " "$hint"
            IFS= read -r ans || { printf "\n"; exit 1; }
            case "$ans" in
                [Yy]*) HEADLESS=yes ;;
                [Nn]*) HEADLESS=no ;;
                *)     HEADLESS=$guess ;;
            esac
        else
            HEADLESS=$guess
        fi
    fi
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "${HEADLESS_FILE%/*}"
        printf '%s\n' "$HEADLESS" > "$HEADLESS_FILE"
    fi
else
    HEADLESS=no
fi

# Ask for your password once, up front, and answer every later prompt with
# it — both the steps that honor sudo's cache (kept warm below) and the
# cask pkg installers that deliberately do not (Homebrew resets sudo's
# timestamp for those, but honors SUDO_ASKPASS). The password is held in a
# 600-permission temp file only for this run, overwritten and deleted on
# exit. (On APFS the overwrite is best effort — copy-on-write can keep old
# blocks — so FileVault is the real at-rest protection.)
ASKPASS_DIR=""
cleanup_askpass() {
    [ -n "$ASKPASS_DIR" ] || return 0
    [ -f "$ASKPASS_DIR/pw" ] && dd if=/dev/zero of="$ASKPASS_DIR/pw" bs=1k count=1 conv=notrunc 2>/dev/null
    rm -rf "$ASKPASS_DIR"
    ASKPASS_DIR=""
}
if [ "$PLATFORM" = mac ] && [ "$DRY_RUN" = false ] && [ -t 0 ]; then
    trap cleanup_askpass EXIT INT TERM
    tries=0
    while :; do
        printf "Password (asked once, then answers the installer prompts for you): "
        IFS= read -rs PW; printf "\n"
        # on a machine with Touch ID for sudo, a fingerprint tap may satisfy
        # this check instead of the typed password — that is fine, the taps
        # then cover the installers too
        if printf '%s\n' "$PW" | sudo -S -v 2>/dev/null; then break; fi
        tries=$((tries+1))
        if [ "$tries" -ge 3 ]; then printf "That password did not work three times — stopping.\n"; PW=""; exit 1; fi
        printf "That password did not work — try again.\n"
    done
    ASKPASS_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup.XXXXXX")" || exit 1
    chmod 700 "$ASKPASS_DIR"
    (umask 077; printf '%s\n' "$PW" > "$ASKPASS_DIR/pw")
    PW=""
    printf '#!/bin/sh\nexec cat "%s"\n' "$ASKPASS_DIR/pw" > "$ASKPASS_DIR/askpass"
    chmod 700 "$ASKPASS_DIR/askpass"
    export SUDO_ASKPASS="$ASKPASS_DIR/askpass"
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
        run bash "$SCRIPT_DIR/linux/packages.sh" "$PROFILE" || return 1
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
    # brew's parallel download output can scroll a live 'Password:' prompt
    # off-screen, which looks exactly like a hang — say up front whether any
    # prompt can appear at all, so a long silence reads correctly
    if [ -n "${SUDO_ASKPASS:-}" ]; then
        info "installer passwords are answered automatically — a long pause is a download or install, never a hidden prompt"
    elif [ -t 0 ]; then
        warn "no stored password — pkg installers WILL prompt below, and the prompt can get buried by download output; if this looks stuck, type your password and press Enter"
    fi
    # If the only things a bundle could not install are App Store apps, the
    # step still succeeds with a warning: mas needs an App Store sign-in that
    # a fresh machine does not have yet — and a VM cannot have at all.
    bundle_one() {
        run brew bundle $bundle_flags --file="$1" && return 0
        [ "$DRY_RUN" = true ] && return 1
        local missing
        missing="$(HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle check --verbose --file="$1" 2>&1 \
            | sed -n 's/^→ \(.*\) needs to be.*$/\1/p')"
        if [ -n "$missing" ] && [ "$(printf '%s\n' "$missing" | grep -cv '^App ')" -eq 0 ]; then
            warn "App Store apps skipped (sign in, then re-run): $(printf '%s\n' "$missing" | sed 's/^App //' | awk 'NR>1 { printf ", " } { printf "%s", $0 } END { print "" }')"
            return 0
        fi
        return 1
    }
    bundle_one "$SCRIPT_DIR/Brewfile" || return 1
    bundle_one "$SCRIPT_DIR/Brewfile.$PROFILE" || return 1
}

# Desktop (GUI) apps on Linux come from Flathub — the cross-distro analogue
# of the cask sections: linux/apps.txt on every desktop machine, plus
# linux/apps.<profile>.txt for that kind only. Headless machines never get
# this step (decided above, remembered in ~/.config/dotfiles/headless).
do_flatpak() {
    local flags=""
    [ "$UPGRADE" = true ] && flags="--upgrade"
    run bash "$SCRIPT_DIR/linux/apps.sh" "$PROFILE" $flags
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

# 1Password's SSH agent serves the keys ssh/config.macos points at. Its
# toggle lives in an UNOFFICIAL file (settings.json inside the app's group
# container) — a private format an update may move or ignore, and the
# running app rewrites it on quit, clobbering outside edits. So: check
# before touching anything, edit only with the app closed (quit, merge the
# key with jq, relaunch), keep a .bak, and trust only the agent socket
# actually appearing as proof the edit took. doctor.sh checks the socket.
OP_GROUP="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password"
OP_SOCK="$OP_GROUP/t/agent.sock"
OP_SETTINGS="$OP_GROUP/Library/Application Support/1Password/Data/settings/settings.json"

do_1password_agent() {
    [ -d "/Applications/1Password.app" ] || { info "1Password is not installed — skipping"; return 0; }
    [ -S "$OP_SOCK" ] && { ok "agent already on (socket present)"; return 0; }
    command -v jq >/dev/null 2>&1 || { warn "jq missing (the packages step installs it) — re-run ./setup.sh"; return 0; }
    if [ ! -f "$OP_SETTINGS" ]; then
        warn "1Password has no settings file yet — open it, sign in, then re-run ./setup.sh"
        return 0
    fi
    if jq -e '."sshAgent.enabled" == true' "$OP_SETTINGS" >/dev/null 2>&1; then
        if [ "$DRY_RUN" = true ]; then info "toggle already on — would launch 1Password and wait for the agent socket"; return 0; fi
        info "toggle already on but no agent socket — launching 1Password (unlock it if it asks)"
        open -ga 1Password
    else
        if [ "$DRY_RUN" = true ]; then info "would quit 1Password, set sshAgent.enabled=true, relaunch"; return 0; fi
        local was_running=false
        if pgrep -xq 1Password; then
            was_running=true
            info "quitting 1Password to flip its SSH-agent toggle (editing while it runs gets overwritten) — it relaunches right after"
            osascript -e 'tell application "1Password" to quit' >/dev/null 2>&1
            local waited=0
            while pgrep -xq 1Password; do
                if [ "$waited" -ge 15 ]; then
                    warn "1Password did not quit — flip it yourself: 1Password > Settings > Developer > 'Use the SSH agent'"
                    return 0
                fi
                sleep 1; waited=$((waited+1))
            done
        fi
        local tmp="$OP_SETTINGS.new"
        if ! jq '. + {"sshAgent.enabled": true}' "$OP_SETTINGS" > "$tmp" 2>/dev/null || ! jq -e . "$tmp" >/dev/null 2>&1; then
            rm -f "$tmp"
            warn "could not edit the settings file (1Password changed its format?) — flip it in 1Password > Settings > Developer"
            [ "$was_running" = true ] && open -ga 1Password
            return 0
        fi
        cp "$OP_SETTINGS" "$OP_SETTINGS.bak"   # unofficial format — keep an undo
        mv "$tmp" "$OP_SETTINGS"
        ok "sshAgent.enabled set (previous settings kept as settings.json.bak)"
        info "$([ "$was_running" = true ] && echo re)launching 1Password — unlock it if it asks"
        open -ga 1Password
    fi
    # the socket appearing is the only real proof this unofficial edit took
    local waited=0
    until [ -S "$OP_SOCK" ]; do
        if [ "$waited" -ge 30 ]; then
            warn "no agent socket after 30s — unlock 1Password and check with ./doctor.sh; if it never appears, flip it in 1Password > Settings > Developer"
            return 0
        fi
        sleep 1; waited=$((waited+1))
    done
    ok "agent socket is up — 1Password is serving your SSH keys"
}

do_macos_defaults() { run bash "$SCRIPT_DIR/macos-defaults.sh"; }

# Dock layout is declarative: dock/<profile>.txt lists the apps in order,
# and the Dock is set to exactly that list. Edit the file to change it.
# Entries are plain app names ("iTerm", "Visual Studio Code"), found in the
# standard app folders, capitalization ignored; a full /path/to.app also
# works for anything unusual. Deliberately NOT fuzzy: this list replaces the
# whole Dock, so a name must match exactly one thing or be skipped — but a
# miss warns with the installed apps whose names contain it.
DOCK_APP_DIRS=(/Applications /Applications/Utilities /System/Applications /System/Applications/Utilities "$HOME/Applications")

dock_resolve() { # name-or-path -> absolute app path on stdout
    case "$1" in /*) printf '%s\n' "$1"; [ -e "$1" ]; return ;; esac
    local d hit
    for d in "${DOCK_APP_DIRS[@]}"; do
        [ -e "$d/$1.app" ] && { printf '%s\n' "$d/$1.app"; return 0; }
        [ -e "$d/$1" ]     && { printf '%s\n' "$d/$1"; return 0; }
    done
    for d in "${DOCK_APP_DIRS[@]}"; do
        hit="$(find "$d" -maxdepth 1 \( -iname "$1.app" -o -iname "$1" \) 2>/dev/null | head -1)"
        [ -n "$hit" ] && { printf '%s\n' "$hit"; return 0; }
    done
    return 1
}

dock_suggest() { # name -> comma-joined installed apps containing it
    local d
    for d in "${DOCK_APP_DIRS[@]}"; do
        find "$d" -maxdepth 1 -iname "*$1*.app" 2>/dev/null
    done | sed 's|.*/||; s|\.app$||' | sort -u \
         | awk 'NR>1 { printf ", " } { printf "%s", $0 } END { print "" }'
}

do_dock() {
    local list="$SCRIPT_DIR/dock/$PROFILE.txt"
    [ "$DOCK" = false ] && { info "off by default (replaces the current Dock) — pass --dock to apply dock/$PROFILE.txt"; return 0; }
    [ -f "$list" ] || { info "no dock/$PROFILE.txt in the repo — skipping"; return 0; }
    command -v dockutil >/dev/null 2>&1 || { warn "dockutil not installed (it is in the Brewfile) — skipping"; return 0; }
    if [ "$DRY_RUN" = true ]; then info "would set the Dock from dock/$PROFILE.txt"; return 0; fi
    dockutil --remove all --no-restart >/dev/null 2>&1
    local app path hint missing=""
    while IFS= read -r app; do
        case "$app" in ''|\#*) continue ;; esac
        if path="$(dock_resolve "$app")"; then
            dockutil --add "$path" --no-restart >/dev/null 2>&1 || warn "could not add ${app##*/}"
        elif hint="$(dock_suggest "$app")" && [ -n "$hint" ]; then
            warn "'$app' not found — installed apps matching it: $hint (fix the name in dock/$PROFILE.txt)"
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
fmt_secs() { if [ "$1" -ge 60 ]; then printf '%dm%02ds' $(($1/60)) $(($1%60)); else printf '%ds' "$1"; fi; }

# Steps are collected first so each one can show its place in the whole run.
STEPS=()
# ${STEPS[@]+...}: bash 3.2 + set -u treat expanding an empty array as unbound
step() { STEPS=(${STEPS[@]+"${STEPS[@]}"} "$1|$2"); }

run_steps() {
    local total=${#STEPS[@]} i=0 s title fn t0
    FAILED=""
    for s in "${STEPS[@]}"; do
        title="${s%|*}"; fn="${s#*|}"; i=$((i+1))
        printf "\n%s▸ %s%s  %s[%d/%d]%s\n" "$BOLD" "$title" "$RESET" "$DIM" "$i" "$total" "$RESET"
        t0=$SECONDS
        if "$fn"; then
            printf "  %s✓ done in %s%s\n" "$DIM" "$(fmt_secs $((SECONDS-t0)))" "$RESET"
        else
            FAILED="$FAILED$title, "
            printf "  %s✗ %s failed after %s — continuing%s\n" "$RED" "$title" "$(fmt_secs $((SECONDS-t0)))" "$RESET"
        fi
    done
}

# ── The run itself ──────────────────────────────────────────────────────
printf "\n%s┌─ dotfiles %s%s\n" "$BOLD" "$([ "$DRY_RUN" = true ] && echo "setup (dry run)" || echo setup)" "$RESET"
if [ "$PLATFORM" = mac ]; then
    printf "%s│%s  %s%s · profile %s · %s%s\n" "$BOLD" "$RESET" "$DIM" "$(scutil --get ComputerName 2>/dev/null || hostname)" "$PROFILE" \
        "$([ "$UPGRADE" = true ] && echo "install + upgrade" || echo "install missing only")" "$RESET"
else
    printf "%s│%s  %s%s · profile %s · %s · %s%s\n" "$BOLD" "$RESET" "$DIM" "$(hostname)" "$PROFILE" \
        "$([ "$HEADLESS" = yes ] && echo "headless (no desktop apps)" || echo "desktop")" \
        "$([ "$UPGRADE" = true ] && echo "install + upgrade" || echo "install missing only")" "$RESET"
fi
printf "%s└─%s\n" "$BOLD" "$RESET"

# To skip a step for one run, comment out its line.
if [ "$PLATFORM" = mac ]; then
    step "Xcode Command Line Tools"        do_xcode
    step "Homebrew"                        do_brew
    # preferences run before packages on purpose: they enable Touch ID for
    # sudo, so the pkg-cask installers below prompt with a fingerprint tap
    # instead of a typed password (Homebrew ignores cached sudo for those)
    step "macOS preferences"               do_macos_defaults
    step "Packages (core + $PROFILE)"      do_packages
    step "Directories"                     do_dirs
    step "Dotfile symlinks"                do_symlinks
    step "Runtimes (mise)"                 do_runtimes
    step "VS Code extensions"              do_vscode
    step "fzf shell integration"           do_fzf
    step "iTerm2 shell integration"        do_iterm2
    step "1Password SSH agent"             do_1password_agent
    step "Dock layout"                     do_dock
    step "Health check"                    do_doctor
else
    step "Packages (core + $PROFILE)"      do_packages
    if [ "$HEADLESS" = no ]; then
        step "Desktop apps (core + $PROFILE)"  do_flatpak
    fi
    step "Directories"                     do_dirs
    step "Dotfile symlinks"                do_symlinks
    step "Runtimes (mise)"                 do_runtimes
    step "VS Code extensions"              do_vscode
    step "Health check"                    do_doctor
fi

run_steps

# ── Summary ─────────────────────────────────────────────────────────────
TOTAL_TIME="$(fmt_secs $SECONDS)"
printf "\n"
if [ -n "$FAILED" ]; then
    printf "%s%s✗ %d of %d steps failed%s %s(%s)%s\n" "$BOLD" "$RED" \
        "$(printf '%s' "$FAILED" | awk -F', ' '{print NF-1}')" "${#STEPS[@]}" "$RESET" "$DIM" "$TOTAL_TIME" "$RESET"
    printf "  %s· %s%s\n" "$RED" "${FAILED%, }" "$RESET"
    info "each error is printed above, at the end of its '▸ <step>' section"
    info "fix the cause and re-run ./setup.sh — finished steps repeat harmlessly"
    exit 1
fi
if [ "$DRY_RUN" = true ]; then info "dry run — nothing was changed ($TOTAL_TIME)"; exit 0; fi
printf "  %s%s✓ All %d steps done in %s.%s\n" "$BOLD" "$GREEN" "${#STEPS[@]}" "$TOTAL_TIME" "$RESET"
info "manual follow-ups (sign-ins, licenses): see Post-Setup in README.md"
