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

# ─── Progress ───────────────────────────────────────────────────────────
progress() { # current total
    local cur=$1 total=$2 width=30 filled i=0
    [ "$total" -eq 0 ] && return 0
    filled=$(( cur * width / total ))
    printf "  %s[%s" "$DIM" "$RESET"
    while [ $i -lt $width ]; do
        if [ $i -lt $filled ]; then printf "%s■%s" "$GREEN" "$RESET"; else printf "%s·%s" "$DIM" "$RESET"; fi
        i=$((i+1))
    done
    printf "%s]%s %s%d%%%s\n" "$DIM" "$RESET" "$BOLD" $(( cur * 100 / total )) "$RESET"
}

step_header() { printf "\n%s%s▸ [%d/%d] %s%s\n" "$BOLD" "$CYAN" "$1" "$2" "$3" "$RESET"; }

# ─── Spinner (for work that prints nothing for a while) ─────────────────
SPIN_PID=""
spin_start() {
    [ "$INTERACTIVE" = false ] && { printf "  %s%s…%s\n" "$DIM" "$1" "$RESET"; return 0; }
    printf "\033[?25l"
    ( while :; do
        for c in '|' '/' '-' '\'; do
            printf "\r  %s%s%s %s%s" "$CYAN" "$c" "$RESET" "$DIM" "$1"
            sleep 1
        done
      done ) 2>/dev/null &
    SPIN_PID=$!
}
spin_stop() {
    [ -z "$SPIN_PID" ] && return 0
    kill "$SPIN_PID" 2>/dev/null
    wait "$SPIN_PID" 2>/dev/null
    SPIN_PID=""
    printf "\r\033[2K\033[?25h"
}

# ─── Checkbox picker ────────────────────────────────────────────────────
# checkbox_menu "key1 key2 ..." label_fn detail_fn [init_fn]
#   label_fn KEY   -> the name shown
#   detail_fn KEY  -> dim text after the name
#   init_fn KEY    -> exit 0 to start checked (default: everything checked)
# Result lands in CB_SELECTED.
# always give the cursor back, however we exit
trap 'printf "\033[?25h"' EXIT INT TERM

CB_KEYS=""; CB_STATE=""; CB_SELECTED=""
CB_LABEL_FN=""; CB_DETAIL_FN=""

# NB: braces are required — $10 would parse as ${1}0, silently dropping item 10
cb_get() { local idx="$1"; set -- $CB_STATE; eval "echo \${$(( idx + 1 ))}"; }
cb_set() { local i=0 out="" v; for v in $CB_STATE; do
               if [ $i -eq "$1" ]; then out="$out $2"; else out="$out $v"; fi; i=$((i+1)); done
           CB_STATE="$out"; }

cb_render() { # cursor_index
    local i=0 k mark pointer
    for k in $CB_KEYS; do
        if [ "$(cb_get $i)" = 1 ]; then mark="${GREEN}[x]${RESET}"; else mark="${DIM}[ ]${RESET}"; fi
        if [ $i -eq "$1" ]; then pointer="${CYAN}▸${RESET}"; else pointer=" "; fi
        printf "\033[2K   %s %s %-26s %s%s%s\n" "$pointer" "$mark" \
            "$($CB_LABEL_FN "$k")" "$DIM" "$($CB_DETAIL_FN "$k")" "$RESET"
        i=$((i+1))
    done
}

cb_read_key() {
    local k rest
    IFS= read -rsn1 k || { echo enter; return; }
    case "$k" in
        "")   echo enter ;;
        " ")  echo space ;;
        j|J)  echo down ;;
        k|K)  echo up ;;
        a|A)  echo all ;;
        q|Q)  echo quit ;;
        $'\033')
            IFS= read -rsn2 rest || { echo other; return; }
            case "$rest" in "[A") echo up ;; "[B") echo down ;; *) echo other ;; esac ;;
        *)    echo other ;;
    esac
}

cb_collect() { CB_SELECTED=""; local i=0 k
    for k in $CB_KEYS; do [ "$(cb_get $i)" = 1 ] && CB_SELECTED="$CB_SELECTED $k"; i=$((i+1)); done; }

checkbox_menu() {
    local i n=0 k cur=0 key any init_fn="${4:-}"
    CB_KEYS="$1"; CB_LABEL_FN="$2"; CB_DETAIL_FN="$3"; CB_STATE=""
    for k in $CB_KEYS; do
        if [ -n "$init_fn" ] && ! $init_fn "$k"; then CB_STATE="$CB_STATE 0"; else CB_STATE="$CB_STATE 1"; fi
        n=$((n+1))
    done
    [ "$n" -eq 0 ] && { CB_SELECTED=""; return 0; }

    if [ -z "$RESET" ] || [ "$INTERACTIVE" = false ]; then cb_numeric "$n"; return; fi

    printf "  %s↑↓ or j/k move · space toggles · a all · enter accepts%s\n\n" "$DIM" "$RESET"
    printf "\033[?25l"
    cb_render "$cur"
    while :; do
        key="$(cb_read_key)"
        case "$key" in
            up)    cur=$(( cur > 0 ? cur - 1 : n - 1 )) ;;
            down)  cur=$(( cur < n - 1 ? cur + 1 : 0 )) ;;
            space) if [ "$(cb_get $cur)" = 1 ]; then cb_set $cur 0; else cb_set $cur 1; fi ;;
            all)   any=0; for i in $CB_STATE; do [ "$i" = 0 ] && any=1; done
                   i=0; CB_STATE=""; while [ $i -lt $n ]; do CB_STATE="$CB_STATE $any"; i=$((i+1)); done ;;
            quit)  printf "\033[?25h\n  Nothing was changed.\n\n"; exit 0 ;;
            enter) break ;;
        esac
        printf "\033[%dA" "$n"
        cb_render "$cur"
    done
    printf "\033[?25h"
    cb_collect
}

cb_numeric() { # n — fallback when the terminal cannot redraw
    local n="$1" i k pick
    while :; do
        i=0
        for k in $CB_KEYS; do
            if [ "$(cb_get $i)" = 1 ]; then printf "   %2d  [x] %-26s %s%s%s\n" $((i+1)) "$($CB_LABEL_FN "$k")" "$DIM" "$($CB_DETAIL_FN "$k")" "$RESET"
            else printf "   %2d  [ ] %-26s %s%s%s\n" $((i+1)) "$($CB_LABEL_FN "$k")" "$DIM" "$($CB_DETAIL_FN "$k")" "$RESET"; fi
            i=$((i+1))
        done
        [ "$INTERACTIVE" = false ] && break
        printf "\n  %s?%s Numbers to toggle (e.g. 2 5), or enter to accept " "$BOLD" "$RESET"
        read -r pick || pick=""
        [ -z "$pick" ] && break
        for i in $pick; do
            case "$i" in ''|*[!0-9]*) continue ;; esac
            [ "$i" -ge 1 ] && [ "$i" -le "$n" ] || continue
            if [ "$(cb_get $((i-1)))" = 1 ]; then cb_set $((i-1)) 0; else cb_set $((i-1)) 1; fi
        done
        printf "\n"
    done
    cb_collect
}
