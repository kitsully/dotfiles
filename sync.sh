#!/bin/bash
# Fold this machine's current state back into the repo, then commit.
#
# Symlinked configs (zsh, git, nvim, ...) already show up in `git status`
# on their own. This script is for the things that do NOT: packages you
# installed with brew, VS Code extensions, and the iTerm2 profile, which
# all drift silently until something notices.
#
# Targets bash 3.2 (the macOS system bash).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COLS=66
. "$SCRIPT_DIR/lib/ui.sh"

PROFILE=""
DRY_RUN=false
ASSUME_YES=false
DO_COMMIT=true

usage() {
    cat <<USAGE
${BOLD}Dotfiles Sync${RESET} — bring the repo back in line with this machine

  ${BOLD}./sync.sh${RESET}              pick what to fold in, then commit
  ${BOLD}./sync.sh --dry-run${RESET}    show what drifted and stop

${BOLD}Flags${RESET}
  --personal | --work    which profile this machine uses (default: guessed)
  -n, --dry-run          report only; change nothing
  -y, --yes              accept the defaults, no questions
      --no-commit        update the files but do not commit
  -h, --help             this message
USAGE
    exit "${1:-1}"
}

for arg in "$@"; do
    case "$arg" in
        --work)       PROFILE=work ;;
        --personal)   PROFILE=personal ;;
        -n|--dry-run) DRY_RUN=true ;;
        -y|--yes)     ASSUME_YES=true ;;
        --no-commit)  DO_COMMIT=false ;;
        -h|--help)    usage 0 ;;
        *) printf "%sError:%s unknown flag '%s'\n\n" "$RED" "$RESET" "$arg"; usage ;;
    esac
done

INTERACTIVE=true
{ [ "$ASSUME_YES" = true ] || [ ! -t 0 ] || [ ! -t 1 ]; } && INTERACTIVE=false

[ -z "$PROFILE" ] && { [ -d "/Applications/Setapp.app" ] && PROFILE=personal || PROFILE=work; }

TMP="${TMPDIR:-/tmp}/dotfiles-sync.$$"
mkdir -p "$TMP"
# also restores the cursor: this replaces the trap lib/ui.sh set
trap 'rm -rf "$TMP"; printf "\033[?25h"' EXIT INT TERM

EXT_FILE="$SCRIPT_DIR/vscode/extensions.txt"
ITERM_FILE="$SCRIPT_DIR/iterm2/Default.json"
PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

BREW_DRIFT=no;  BREW_DETAIL="in sync"
EXT_DRIFT=no;   EXT_DETAIL="in sync"
ITERM_DRIFT=no; ITERM_DETAIL="in sync"

banner "Dotfiles Sync" "$PROFILE profile$([ "$DRY_RUN" = true ] && echo ' · dry run')"
printf "\n"

# ─── Detect ─────────────────────────────────────────────────────────────
entries() { grep -hE '^(tap|brew|cask|mas) ' "$@" 2>/dev/null | awk -F'#' '{print $1}' | awk '{$1=$1};1'; }

# key<TAB>original. mas apps are keyed by id — the display name brew reports
# ("CARROTweather") often differs from the one in the Brewfile ("CARROT Weather").
keyed() {
    awk '{ line=$0
           if ($0 ~ /^mas /) { match($0, /id: [0-9]+/); key = "mas " substr($0, RSTART, RLENGTH) }
           else key = $0
           print key "\t" line }' | sort -u -t"$(printf '\t')" -k1,1
}
lookup() { awk -F'\t' 'NR==FNR{want[$0]=1;next} want[$1]{print $2}' "$1" "$2"; }

spin_start "checking what changed on this machine"

if command -v brew >/dev/null 2>&1; then
    brew bundle dump --file=- 2>/dev/null | grep -E '^(tap|brew|cask|mas) ' \
        | awk -F'#' '{print $1}' | awk '{$1=$1};1' | keyed > "$TMP/live_kv.txt"
    entries "$SCRIPT_DIR/Brewfile" "$SCRIPT_DIR/Brewfile.$PROFILE" | keyed > "$TMP/tracked_kv.txt"
    cut -f1 "$TMP/live_kv.txt"    | sort -u > "$TMP/live_k.txt"
    cut -f1 "$TMP/tracked_kv.txt" | sort -u > "$TMP/tracked_k.txt"
    comm -23 "$TMP/live_k.txt" "$TMP/tracked_k.txt" > "$TMP/added_k.txt"
    comm -13 "$TMP/live_k.txt" "$TMP/tracked_k.txt" > "$TMP/removed_k.txt"
    lookup "$TMP/added_k.txt"   "$TMP/live_kv.txt"    > "$TMP/added.txt"
    lookup "$TMP/removed_k.txt" "$TMP/tracked_kv.txt" > "$TMP/removed.txt"
    n_add=$(awk 'END{print NR}' "$TMP/added.txt")
    n_rem=$(awk 'END{print NR}' "$TMP/removed.txt")
    if [ "$n_add" -gt 0 ]; then
        BREW_DRIFT=yes; BREW_DETAIL="$n_add to add, $n_rem not installed here"
    elif [ "$n_rem" -gt 0 ]; then
        BREW_DETAIL="in sync ($n_rem not installed here)"
    fi
else
    BREW_DETAIL="brew not found"
fi

if command -v code >/dev/null 2>&1; then
    code --list-extensions 2>/dev/null | sort > "$TMP/ext_live.txt"
    sort "$EXT_FILE" > "$TMP/ext_repo.txt"
    comm -23 "$TMP/ext_live.txt" "$TMP/ext_repo.txt" > "$TMP/ext_add.txt"
    comm -13 "$TMP/ext_live.txt" "$TMP/ext_repo.txt" > "$TMP/ext_rem.txt"
    e_add=$(awk 'END{print NR}' "$TMP/ext_add.txt"); e_rem=$(awk 'END{print NR}' "$TMP/ext_rem.txt")
    if [ "$e_add" -gt 0 ] || [ "$e_rem" -gt 0 ]; then
        EXT_DRIFT=yes; EXT_DETAIL="$e_add added, $e_rem removed"
    fi
else
    EXT_DETAIL="code not on PATH"
fi

if [ -f "$PLIST" ] && command -v plutil >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 \
   && plutil -extract "New Bookmarks" json -o "$TMP/iterm_live.json" "$PLIST" 2>/dev/null; then
    VERDICT="$(python3 - "$TMP/iterm_live.json" "$ITERM_FILE" "$TMP/iterm_new.json" <<'PYEOF'
import json, sys
live = json.load(open(sys.argv[1]))
try:
    repo = json.load(open(sys.argv[2])).get("Profiles", [])
except Exception:
    repo = []
json.dump({"Profiles": live}, open(sys.argv[3], "w"), indent=2, sort_keys=True)
# compare semantically: plutil emits ints where the repo copy has floats
print("SAME" if live == repo else "DIFF")
PYEOF
)"
    [ "$VERDICT" = DIFF ] && { ITERM_DRIFT=yes; ITERM_DETAIL="profile changed"; }
else
    ITERM_DETAIL="iTerm2 plist not readable"
fi

spin_stop

# ─── Report ─────────────────────────────────────────────────────────────
sync_label() {
    case "$1" in
        brew)   echo "Homebrew packages" ;;
        vscode) echo "VS Code extensions" ;;
        iterm2) echo "iTerm2 profile" ;;
    esac
}
sync_detail() {
    case "$1" in
        brew)   echo "$BREW_DETAIL" ;;
        vscode) echo "$EXT_DETAIL" ;;
        iterm2) echo "$ITERM_DETAIL" ;;
    esac
}
sync_drifted() { # exit 0 when this target has something to fold in
    case "$1" in
        brew)   [ "$BREW_DRIFT" = yes ] ;;
        vscode) [ "$EXT_DRIFT" = yes ] ;;
        iterm2) [ "$ITERM_DRIFT" = yes ] ;;
    esac
}

TARGETS="brew vscode iterm2"
DRIFTED=""
for t in $TARGETS; do sync_drifted "$t" && DRIFTED="$DRIFTED $t"; done

if [ -n "$(printf '%s' "${BREW_DRIFT}${EXT_DRIFT}${ITERM_DRIFT}" | tr -d 'no')" ] || [ -n "$DRIFTED" ]; then
    if [ "$BREW_DRIFT" = yes ]; then
        printf "%sNew packages%s\n" "$BOLD" "$RESET"
        while IFS= read -r l; do [ -n "$l" ] && printf "      %s+ %s%s\n" "$GREEN" "$l" "$RESET"; done < "$TMP/added.txt"
        if [ "${n_rem:-0}" -gt 0 ]; then
            printf "  %stracked but not installed here — left alone:%s\n" "$DIM" "$RESET"
            while IFS= read -r l; do [ -n "$l" ] && printf "      %s- %s%s\n" "$DIM" "$l" "$RESET"; done < "$TMP/removed.txt"
        fi
        printf "\n"
    fi
    if [ "$EXT_DRIFT" = yes ]; then
        printf "%sVS Code extensions%s\n" "$BOLD" "$RESET"
        while IFS= read -r l; do [ -n "$l" ] && printf "      %s+ %s%s\n" "$GREEN" "$l" "$RESET"; done < "$TMP/ext_add.txt"
        while IFS= read -r l; do [ -n "$l" ] && printf "      %s- %s%s\n" "$RED" "$l" "$RESET"; done < "$TMP/ext_rem.txt"
        printf "\n"
    fi
fi

cd "$SCRIPT_DIR" || exit 1
GIT_DIRTY="$(git status --porcelain 2>/dev/null)"
if [ -n "$GIT_DIRTY" ]; then
    printf "%sAlready modified in the repo%s\n" "$BOLD" "$RESET"
    printf "%s\n" "$GIT_DIRTY" | while IFS= read -r l; do printf "      %s%s%s\n" "$DIM" "$l" "$RESET"; done
    printf "\n"
fi

if [ -z "$DRIFTED" ] && [ -z "$GIT_DIRTY" ]; then
    rule; ok "Everything is already in sync."; printf "\n"; exit 0
fi

if [ "$DRY_RUN" = true ]; then
    rule; warn "Dry run — nothing was changed."; printf "\n"; exit 0
fi

# ─── Choose ─────────────────────────────────────────────────────────────
SELECTED=""
if [ -n "$DRIFTED" ]; then
    printf "%sWhat should I fold into the repo?%s\n" "$BOLD" "$RESET"
    checkbox_menu "$TARGETS" sync_label sync_detail sync_drifted
    SELECTED="$CB_SELECTED"
fi

# ─── Apply ──────────────────────────────────────────────────────────────
TOTAL=0; for t in $SELECTED; do TOTAL=$((TOTAL+1)); done
IDX=0
for t in $SELECTED; do
    IDX=$((IDX+1))
    step_header "$IDX" "$TOTAL" "$(sync_label "$t")"
    case "$t" in
        brew)
            TARGET="$SCRIPT_DIR/Brewfile.$PROFILE"
            if [ -s "$TMP/added.txt" ]; then
                if [ "$INTERACTIVE" = true ]; then
                    printf "      %s1%s  Brewfile           %s(every machine)%s\n" "$BOLD" "$RESET" "$DIM" "$RESET"
                    printf "      %s2%s  Brewfile.%-9s %s(this machine only)%s\n" "$BOLD" "$RESET" "$PROFILE" "$DIM" "$RESET"
                    printf "  %s?%s Where do these go? %s[2]%s " "$BOLD" "$RESET" "$DIM" "$RESET"
                    read -r pick || pick=""
                    [ "$pick" = 1 ] && TARGET="$SCRIPT_DIR/Brewfile"
                fi
                printf "\n# --- added by sync.sh ---\n" >> "$TARGET"
                cat "$TMP/added.txt" >> "$TARGET"
                ok "appended $(awk 'END{print NR}' "$TMP/added.txt") entries to $(basename "$TARGET")"
            fi ;;
        vscode)
            code --list-extensions 2>/dev/null | sort > "$EXT_FILE"
            ok "rewrote vscode/extensions.txt" ;;
        iterm2)
            cp "$TMP/iterm_new.json" "$ITERM_FILE"
            ok "rewrote iterm2/Default.json" ;;
    esac
    progress "$IDX" "$TOTAL"
done

# ─── Commit ─────────────────────────────────────────────────────────────
printf "\n"; rule
if [ "$DO_COMMIT" = false ]; then
    info "--no-commit given; review with: git diff"; printf "\n"; exit 0
fi
if [ -z "$(git status --porcelain)" ]; then
    ok "Nothing to commit."; printf "\n"; exit 0
fi

printf "\n%sReady to commit%s\n\n" "$BOLD" "$RESET"
git status --short | while IFS= read -r l; do printf "      %s%s%s\n" "$DIM" "$l" "$RESET"; done
printf "\n"

if ask_yn "Commit these changes?" Y; then
    MSG="Sync dotfiles from $(hostname -s)"
    if [ "$INTERACTIVE" = true ]; then
        printf "  %s?%s Message %s[%s]%s " "$BOLD" "$RESET" "$DIM" "$MSG" "$RESET"
        read -r custom || custom=""
        [ -n "$custom" ] && MSG="$custom"
    fi
    git add -A && git commit -q -m "$MSG" && ok "committed: $(git log -1 --format=%h) $MSG"
    printf "\n"
    if ask_yn "Push to origin?" N; then git push && ok "pushed"; else info "not pushed — run: git push"; fi
else
    info "left uncommitted"
fi
printf "\n"
