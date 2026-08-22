#!/bin/bash
# Shared presentation helpers for setup.sh and sync.sh.
# Targets bash 3.2 (the macOS system bash).

COLS="${COLS:-66}"
INTERACTIVE="${INTERACTIVE:-true}"

# FORCE_COLOR=1 keeps colour when piping (e.g. into `less -R`); NO_COLOR removes it.
if [ -n "${FORCE_COLOR:-}" ] || { [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && command -v tput >/dev/null 2>&1 \
   && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; }; then
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RESET="$(tput sgr0)"
    RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"; CYAN="$(tput setaf 6)"
else
    BOLD=""; DIM=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""
fi

repeat() { local n=$1 c=$2 i=0; while [ $i -lt "$n" ]; do printf '%s' "$c"; i=$((i+1)); done; }
rule()   { printf "%s" "$DIM"; repeat $COLS "─"; printf "%s\n" "$RESET"; }

bline() { # text [style] — padding is measured on the plain text, not the escapes
    local text="$1" style="${2:-}" pad=$(( COLS - 4 - ${#1} ))
    [ $pad -lt 0 ] && pad=0
    printf "%s│%s  %s%s%s" "$BLUE" "$RESET" "$style" "$text" "$RESET"
    repeat $pad " "; printf "%s│%s\n" "$BLUE" "$RESET"
}

banner() { # title subtitle
    printf "\n%s╭" "$BLUE"; repeat $((COLS-2)) "─"; printf "╮%s\n" "$RESET"
    bline "$1" "$BOLD"
    bline "$2" "$DIM"
    printf "%s╰" "$BLUE"; repeat $((COLS-2)) "─"; printf "╯%s\n" "$RESET"
}

ok()   { printf "  %s✓%s %s\n" "$GREEN"  "$RESET" "$1"; }
bad()  { printf "  %s✗%s %s\n" "$RED"    "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
info() { printf "  %s%s%s\n"   "$DIM"    "$1"     "$RESET"; }

ask_yn() { # question default(Y|N) -> 0 for yes
    local q="$1" def="${2:-Y}" ans prompt
    if [ "$INTERACTIVE" = false ]; then
        [ "$def" = "Y" ] && return 0 || return 1
    fi
    if [ "$def" = "Y" ]; then prompt="[Y/n]"; else prompt="[y/N]"; fi
    printf "  %s?%s %s %s%s%s " "$BOLD" "$RESET" "$q" "$DIM" "$prompt" "$RESET"
    read -r ans || ans=""
    ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
    [ -z "$ans" ] && ans="$(printf '%s' "$def" | tr '[:upper:]' '[:lower:]')"
    [ "$ans" = "y" ] || [ "$ans" = "yes" ]
}
