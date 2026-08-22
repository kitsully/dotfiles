#!/bin/bash
# One front door for the dotfiles: set up a machine, sync it back, or check it.
#
# Everything here delegates to setup.sh / sync.sh / doctor.sh, which still
# work on their own with flags if you would rather skip the menu.
#
# Targets bash 3.2 (the macOS system bash).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COLS=66
. "$SCRIPT_DIR/lib/ui.sh"

INTERACTIVE=true
{ [ ! -t 0 ] || [ ! -t 1 ]; } && INTERACTIVE=false

usage() {
    cat <<USAGE
${BOLD}Dotfiles${RESET}

  ${BOLD}./dotfiles.sh${RESET}          menu: set up, sync, or check this machine

Straight to one of them, skipping the menu:

  ${BOLD}./dotfiles.sh setup${RESET} [flags]   same as ./setup.sh
  ${BOLD}./dotfiles.sh sync${RESET}  [flags]   same as ./sync.sh
  ${BOLD}./dotfiles.sh doctor${RESET}          same as ./doctor.sh

Any extra flags are passed straight through, so
${DIM}./dotfiles.sh setup --work --dry-run${RESET} works as you would expect.
USAGE
    exit "${1:-1}"
}

# Direct dispatch — no menu.
if [ $# -gt 0 ]; then
    cmd="$1"; shift
    case "$cmd" in
        setup)      exec bash "$SCRIPT_DIR/setup.sh"  "$@" ;;
        sync)       exec bash "$SCRIPT_DIR/sync.sh"   "$@" ;;
        doctor)     exec bash "$SCRIPT_DIR/doctor.sh" "$@" ;;
        -h|--help)  usage 0 ;;
        *) printf "%sError:%s unknown command '%s'\n\n" "$RED" "$RESET" "$cmd"; usage ;;
    esac
fi

if [ "$INTERACTIVE" = false ]; then
    printf "%sError:%s no terminal to show the menu on — give a command instead.\n\n" "$RED" "$RESET"
    usage
fi

banner "Dotfiles" "$([ "$(uname)" = Darwin ] && echo macOS || echo Linux) · $(cd "$SCRIPT_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"

# A quick sense of whether anything is outstanding, so the menu is informative.
cd "$SCRIPT_DIR" || exit 1
dirty="$(git status --porcelain 2>/dev/null | awk 'END{print NR}')"

printf "\n%sWhat would you like to do?%s\n\n" "$BOLD" "$RESET"
printf "    %s1%s  Set up this machine   %sinstall packages, link configs%s\n" "$BOLD" "$RESET" "$DIM" "$RESET"
printf "    %s2%s  Sync back to the repo %spick up local changes%s%s\n" "$BOLD" "$RESET" "$DIM" \
       "$([ "$dirty" -gt 0 ] && printf ' · %s uncommitted' "$dirty")" "$RESET"
printf "    %s3%s  Check this machine    %sverify tools, symlinks, config%s\n" "$BOLD" "$RESET" "$DIM" "$RESET"
printf "    %sq%s  Quit\n\n" "$BOLD" "$RESET"
printf "  %s?%s Choice %s[1]%s " "$BOLD" "$RESET" "$DIM" "$RESET"
read -r choice || choice=""

case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')" in
    2|sync)         exec bash "$SCRIPT_DIR/sync.sh" ;;
    3|check|doctor) exec bash "$SCRIPT_DIR/doctor.sh" ;;
    q|quit)         printf "\n  Nothing was changed.\n\n"; exit 0 ;;
    *)              exec bash "$SCRIPT_DIR/setup.sh" ;;
esac
