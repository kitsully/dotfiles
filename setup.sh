#!/bin/bash
# Workstation setup.
#
# Interactive by default: it asks which machine this is, shows you the plan,
# and reports each step as it goes. Pass --yes for an unattended run.
#
# Targets bash 3.2 (the macOS system bash) — no associative arrays, no mapfile.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COLS=66
. "$SCRIPT_DIR/lib/ui.sh"

# ─── Setup-specific output ──────────────────────────────────────────────
# success line for a step that changes something — silent during a dry run,
# where the "would run" lines above it already say what would happen
ok_done() { [ "$DRY_RUN" = true ] && return 0; ok "$1"; }

# ─── Step registry ──────────────────────────────────────────────────────
# Keys are ordered; label/detail/skip-flag looked up by case (bash 3.2 safe).
MAC_STEPS="xcode brew packages dirs symlinks vscode fzf iterm2 macos_defaults doctor"
LINUX_STEPS="packages dirs symlinks vscode doctor"

step_label() {
    case "$1" in
        xcode)          echo "Xcode Command Line Tools" ;;
        brew)           echo "Homebrew" ;;
        packages)       echo "Packages" ;;
        dirs)           echo "Directories" ;;
        symlinks)       echo "Dotfile symlinks" ;;
        vscode)         echo "VS Code extensions" ;;
        fzf)            echo "FZF shell integration" ;;
        iterm2)         echo "iTerm2 shell integration" ;;
        macos_defaults) echo "macOS preferences" ;;
        doctor)         echo "Health check" ;;
    esac
}

step_detail() {
    case "$1" in
        xcode)          echo "compiler toolchain; may prompt for your password" ;;
        brew)           echo "installed only if missing" ;;
        packages)       if [ "$PLATFORM" = mac ]; then
                            echo "core Brewfile + $PROFILE profile — the long one"
                        else
                            echo "distro packages, then zsh as your login shell"
                        fi ;;
        dirs)           echo "~/Code and ~/Desktop/screenshots" ;;
        symlinks)       echo "links configs into \$HOME (existing files are backed up)" ;;
        vscode)         echo "$(wc -l < "$SCRIPT_DIR/vscode/extensions.txt" | tr -d ' ') extensions" ;;
        fzf)            echo "key bindings and completion" ;;
        iterm2)         echo "downloads the integration script" ;;
        macos_defaults) echo "dock, keyboard, Finder — some need a logout" ;;
        doctor)         echo "verifies everything above" ;;
    esac
}

# ─── Steps ──────────────────────────────────────────────────────────────
run_live() { # run showing indented output
    if [ "$DRY_RUN" = true ]; then info "would run: $*"; return 0; fi
    "$@" 2>&1 | sed 's/^/    /'
}

do_xcode() {
    if xcode-select -p >/dev/null 2>&1; then ok "already installed"; return 0; fi
    if [ "$DRY_RUN" = true ]; then info "would run: xcode-select --install"; return 0; fi
    info "a system dialog will open — click Install, then come back here"
    xcode-select --install 2>/dev/null
    printf "  %s?%s Press enter once the installer has finished " "$BOLD" "$RESET"
    [ "$INTERACTIVE" = true ] && read -r _
    xcode-select -p >/dev/null 2>&1 || return 1
    if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
        info "accepting the Xcode license (needs your password)"
        sudo xcodebuild -license accept || return 1
    fi
    ok "installed"
}

do_brew() {
    if command -v brew >/dev/null 2>&1; then ok "already installed ($(brew --version | head -1))"; return 0; fi
    if [ "$DRY_RUN" = true ]; then info "would install Homebrew"; return 0; fi
    info "downloading the Homebrew installer"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "installed"
}

do_packages() {
    if [ "$PLATFORM" = linux ]; then
        run_live bash "$SCRIPT_DIR/linux/packages.sh" || return 1
        if [ "$(basename "$SHELL")" != "zsh" ] && [ "$DRY_RUN" = false ]; then
            info "setting zsh as your login shell"
            chsh -s "$(command -v zsh)" || warn "could not change shell — do it manually"
        fi
        ok_done "packages installed"
        return 0
    fi

    info "core packages"
    run_live brew bundle --file="$SCRIPT_DIR/Brewfile" || return 1

    local pf="$SCRIPT_DIR/Brewfile.$PROFILE"
    if [ -f "$pf" ]; then
        info "$PROFILE packages"
        run_live brew bundle --file="$pf" || return 1
    fi
    ok_done "packages installed"
}

do_dirs() {
    run_live mkdir -p "$HOME/Code" "$HOME/Desktop/screenshots" || return 1
    ok_done "~/Code, ~/Desktop/screenshots"
}

do_symlinks() { run_live bash "$SCRIPT_DIR/install.sh" || return 1; ok_done "dotfiles linked"; }

do_vscode() {
    if ! command -v code >/dev/null 2>&1; then warn "'code' not on PATH — skipping"; return 0; fi
    local n=0
    while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        n=$((n+1))
        printf "    %s%s%s\n" "$DIM" "$ext" "$RESET"
        [ "$DRY_RUN" = false ] && code --install-extension "$ext" --force >/dev/null 2>&1
    done < "$SCRIPT_DIR/vscode/extensions.txt"
    ok_done "$n extensions"
}

do_fzf() { run_live "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish || return 1; ok_done "installed"; }

do_iterm2() {
    if [ -f "$HOME/.iterm2_shell_integration.zsh" ]; then ok "already present"; return 0; fi
    run_live curl -fsSL https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh" || return 1
    ok_done "downloaded"
}

do_macos_defaults() { run_live bash "$SCRIPT_DIR/macos-defaults.sh" || return 1; ok_done "applied"; }
do_doctor()         { if [ "$DRY_RUN" = true ]; then info "would run doctor.sh"; return 0; fi; bash "$SCRIPT_DIR/doctor.sh" 2>&1 | sed 's/^/    /'; return 0; }

run_step() {
    case "$1" in
        xcode) do_xcode ;; brew) do_brew ;; packages) do_packages ;;
        dirs) do_dirs ;; symlinks) do_symlinks ;; vscode) do_vscode ;;
        fzf) do_fzf ;; iterm2) do_iterm2 ;; macos_defaults) do_macos_defaults ;;
        doctor) do_doctor ;;
    esac
}

# ─── Usage ──────────────────────────────────────────────────────────────
usage() {
    cat <<USAGE
${BOLD}Workstation Setup${RESET}

  ${BOLD}./setup.sh${RESET}                 walk through it interactively
  ${BOLD}./setup.sh --work --yes${RESET}    unattended work-machine setup

${BOLD}Usage:${RESET} $0 [mac|linux] [flags]

Platform is auto-detected when not given.

${BOLD}Profile${RESET} (macOS app set — you are asked if not specified)
  --personal             core Brewfile + Brewfile.personal
  --work                 core Brewfile + Brewfile.work

${BOLD}Mode${RESET}
  -y, --yes              no questions; accept every default
  -n, --dry-run          show what would happen, change nothing
  -h, --help             this message

${BOLD}Skip individual steps${RESET}
  --skip-installs        shorthand for xcode, brew, packages, fzf
  --skip-xcode           --skip-brew            --skip-packages
  --skip-dirs            --skip-symlinks        --skip-vscode
  --skip-fzf             --skip-iterm2          --skip-macos-defaults
  --skip-doctor
USAGE
    exit "${1:-1}"
}

# ─── Arguments ──────────────────────────────────────────────────────────
PLATFORM=""
PROFILE=""
DRY_RUN=false
ASSUME_YES=false
SKIPPED=""

if [ $# -gt 0 ] && [ "${1#--}" = "$1" ] && [ "${1#-}" = "$1" ]; then
    PLATFORM="$1"; shift
    if [ "$PLATFORM" != mac ] && [ "$PLATFORM" != linux ]; then
        printf "%sError:%s unknown platform '%s'\n\n" "$RED" "$RESET" "$PLATFORM"; usage
    fi
fi

for arg in "$@"; do
    case "$arg" in
        --work)     PROFILE=work ;;
        --personal) PROFILE=personal ;;
        -y|--yes)   ASSUME_YES=true ;;
        -n|--dry-run) DRY_RUN=true ;;
        -h|--help)  usage 0 ;;
        --skip-installs) SKIPPED="$SKIPPED xcode brew packages fzf" ;;
        --skip-xcode)          SKIPPED="$SKIPPED xcode" ;;
        --skip-brew)           SKIPPED="$SKIPPED brew" ;;
        --skip-packages)       SKIPPED="$SKIPPED packages" ;;
        --skip-dirs)           SKIPPED="$SKIPPED dirs" ;;
        --skip-symlinks)       SKIPPED="$SKIPPED symlinks" ;;
        --skip-vscode)         SKIPPED="$SKIPPED vscode" ;;
        --skip-fzf)            SKIPPED="$SKIPPED fzf" ;;
        --skip-iterm2)         SKIPPED="$SKIPPED iterm2" ;;
        --skip-macos-defaults) SKIPPED="$SKIPPED macos_defaults" ;;
        --skip-doctor)         SKIPPED="$SKIPPED doctor" ;;
        *) printf "%sError:%s unknown flag '%s'\n\n" "$RED" "$RESET" "$arg"; usage ;;
    esac
done

[ -z "$PLATFORM" ] && { [ "$(uname)" = Darwin ] && PLATFORM=mac || PLATFORM=linux; }

INTERACTIVE=true
{ [ "$ASSUME_YES" = true ] || [ ! -t 0 ] || [ ! -t 1 ]; } && INTERACTIVE=false

is_skipped() { case " $SKIPPED " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# ─── Walkthrough ────────────────────────────────────────────────────────
banner "Workstation Setup" "$([ "$PLATFORM" = mac ] && echo macOS || echo Linux)$([ "$DRY_RUN" = true ] && echo ' · dry run')"

if [ "$PLATFORM" = mac ] && [ -z "$PROFILE" ]; then
    if [ "$INTERACTIVE" = true ]; then
        printf "\n%sWhich machine is this?%s\n\n" "$BOLD" "$RESET"
        printf "    %s1%s  personal  %s— everything, including App Store apps and personal licenses%s\n" "$BOLD" "$RESET" "$DIM" "$RESET"
        printf "    %s2%s  work      %s— leaves out personal-only apps and Docker Desktop%s\n\n" "$BOLD" "$RESET" "$DIM" "$RESET"
        printf "  %s?%s Choice %s[1]%s " "$BOLD" "$RESET" "$DIM" "$RESET"
        read -r choice || choice=""
        case "$choice" in 2|work) PROFILE=work ;; *) PROFILE=personal ;; esac
    else
        PROFILE=personal
    fi
fi
[ -z "$PROFILE" ] && PROFILE=personal

[ "$PLATFORM" = mac ] && ALL_STEPS="$MAC_STEPS" || ALL_STEPS="$LINUX_STEPS"

PLAN=""
for k in $ALL_STEPS; do is_skipped "$k" || PLAN="$PLAN $k"; done

show_plan() {
    printf "\n%sHere is the plan%s  %s(%s profile)%s\n\n" "$BOLD" "$RESET" "$DIM" "$PROFILE" "$RESET"
    local n=0
    for k in $PLAN; do
        n=$((n+1))
        printf "   %s%2d%s  %-26s %s%s%s\n" "$BOLD" "$n" "$RESET" "$(step_label "$k")" "$DIM" "$(step_detail "$k")" "$RESET"
    done
    for k in $ALL_STEPS; do
        is_skipped "$k" && printf "   %s  ·  %-26s skipped%s\n" "$DIM" "$(step_label "$k")" "$RESET"
    done
    printf "\n"
}

customize() {
    printf "\n%sChoose the steps to run%s\n" "$BOLD" "$RESET"
    checkbox_menu "$ALL_STEPS" step_label step_detail
    PLAN="$CB_SELECTED"
}

show_plan

if [ "$INTERACTIVE" = true ]; then
    while :; do
        printf "  %s?%s Proceed? %s[Y]es / [c]ustomize / [q]uit%s " "$BOLD" "$RESET" "$DIM" "$RESET"
        read -r reply || reply=""
        case "$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')" in
            ""|y|yes) break ;;
            c|customize|customize) customize; show_plan ;;
            q|quit|n|no) printf "\n  Nothing was changed.\n\n"; exit 0 ;;
        esac
    done
fi

if [ -z "$(printf '%s' "$PLAN" | tr -d ' ')" ]; then
    printf "\n  No steps selected — nothing to do.\n\n"
    exit 0
fi

# ─── Run ────────────────────────────────────────────────────────────────
TOTAL=0; for k in $PLAN; do TOTAL=$((TOTAL+1)); done
IDX=0; FAILED=""; STARTED=$SECONDS

for k in $PLAN; do
    IDX=$((IDX+1))
    step_header "$IDX" "$TOTAL" "$(step_label "$k")"
    if ! run_step "$k"; then
        bad "$(step_label "$k") failed"
        FAILED="$FAILED $k"
        if [ "$INTERACTIVE" = true ]; then
            ask_yn "Keep going with the remaining steps?" Y || { warn "stopped at your request"; break; }
        fi
    fi
    progress "$IDX" "$TOTAL"
done

# ─── Summary ────────────────────────────────────────────────────────────
ELAPSED=$(( SECONDS - STARTED ))
printf "\n"; rule
if [ -n "$FAILED" ]; then
    printf "%s%s  ✗ Some steps failed:%s%s\n" "$BOLD" "$RED" "$RESET" "$FAILED"
    printf "  %sFix the cause, then re-run — finished steps are skipped or repeat harmlessly.%s\n" "$DIM" "$RESET"
elif [ "$DRY_RUN" = true ]; then
    printf "%s%s  Dry run finished — nothing was changed%s\n" "$BOLD" "$YELLOW" "$RESET"
    printf "  %sRe-run without --dry-run to apply all %d steps.%s\n" "$DIM" "$TOTAL" "$RESET"
else
    printf "%s%s  ✓ All %d steps finished%s  %s(%dm %ds)%s\n" "$BOLD" "$GREEN" "$TOTAL" "$RESET" "$DIM" $((ELAPSED/60)) $((ELAPSED%60)) "$RESET"
fi
rule

printf "\n%sWhat is left for you to do%s\n\n" "$BOLD" "$RESET"
i=1
say() { printf "   %s%d.%s %s\n" "$BOLD" "$i" "$RESET" "$1"; i=$((i+1)); }

if [ "$PLATFORM" = mac ]; then
    say "Sign into 1Password$([ "$PROFILE" = work ] && echo ' with your WORK account') and turn on the SSH agent"
    say "Put your signing key at ~/.ssh/git_signing_key.pub"
    if [ "$PROFILE" = work ]; then
        say "Set a work git identity — see 'Work Git Identity' in the README."
        printf "      %sDo not use 'git config --global': ~/.gitconfig is a symlink into this repo.%s\n" "$DIM" "$RESET"
        say "Sign into the Mac App Store (Drafts and Amphetamine install via mas)"
        say "Sign into Raycast with a work account, not your personal sync"
        say "Activate licenses: Keyboard Maestro, TextExpander, Hazel, Tower, Transmit, BBEdit"
    else
        say "Sign into iCloud / the Mac App Store (needed for the mas installs)"
        say "Sign into Raycast for cloud sync"
        say "Activate licenses: Keyboard Maestro, TextExpander, Setapp"
    fi
    say "Import your iTerm2 profile from backup"
    say "npm install -g @anthropic-ai/claude-code"
    say "Open a new terminal, or run: source ~/.zshrc"
else
    say "Install and configure 1Password with the SSH agent"
    say "Put your signing key at ~/.ssh/git_signing_key.pub"
    say "npm install -g @anthropic-ai/claude-code"
    say "Log out and back in so zsh takes effect"
fi
printf "\n"

[ -n "$FAILED" ] && exit 1
exit 0
