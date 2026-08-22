#!/bin/bash
# Pull this machine's current state back into the repo, then commit.
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
${BOLD}Dotfiles Sync${RESET}  — bring the repo back in line with this machine

  ${BOLD}./sync.sh${RESET}              show what drifted, then offer to update and commit
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

# Guess the profile from a personal-only app being present.
if [ -z "$PROFILE" ]; then
    if [ -d "/Applications/Setapp.app" ]; then PROFILE=personal; else PROFILE=work; fi
fi

TMP="${TMPDIR:-/tmp}/dotfiles-sync.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT INT TERM

banner "Dotfiles Sync" "$PROFILE profile$([ "$DRY_RUN" = true ] && echo ' · dry run')"

CHANGES=0

# ─── 1. Homebrew ────────────────────────────────────────────────────────
# Compare against core + the active profile only. The other profile's
# entries are legitimately absent here and must not count as drift.
printf "\n%sHomebrew packages%s\n" "$BOLD" "$RESET"

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

    # NB: `grep -c` exits 1 on zero matches, so `|| echo 0` would print "0\n0"
    n_add=$(awk 'END{print NR}' "$TMP/added.txt")
    n_rem=$(awk 'END{print NR}' "$TMP/removed.txt")

    if [ "$n_add" -gt 0 ]; then
        warn "$n_add installed here but not tracked"
        while IFS= read -r l; do [ -n "$l" ] && printf "      %s+ %s%s\n" "$GREEN" "$l" "$RESET"; done < "$TMP/added.txt"
        CHANGES=$((CHANGES+1))
    fi
    if [ "$n_rem" -gt 0 ]; then
        warn "$n_rem tracked but not installed here"
        while IFS= read -r l; do [ -n "$l" ] && printf "      %s- %s%s\n" "$RED" "$l" "$RESET"; done < "$TMP/removed.txt"
        info "left alone — remove by hand if you really uninstalled them"
    fi
    [ "$n_add" -eq 0 ] && [ "$n_rem" -eq 0 ] && ok "in sync"
else
    info "brew not found — skipped"
fi

# ─── 2. VS Code extensions ──────────────────────────────────────────────
printf "\n%sVS Code extensions%s\n" "$BOLD" "$RESET"
EXT_FILE="$SCRIPT_DIR/vscode/extensions.txt"
if command -v code >/dev/null 2>&1; then
    code --list-extensions 2>/dev/null | sort > "$TMP/ext_live.txt"
    sort "$EXT_FILE" > "$TMP/ext_repo.txt"
    if diff -q "$TMP/ext_live.txt" "$TMP/ext_repo.txt" >/dev/null; then
        ok "in sync"
    else
        comm -23 "$TMP/ext_live.txt" "$TMP/ext_repo.txt" > "$TMP/ext_add.txt"
        comm -13 "$TMP/ext_live.txt" "$TMP/ext_repo.txt" > "$TMP/ext_rem.txt"
        warn "$(awk 'END{print NR}' "$TMP/ext_add.txt") installed but not tracked, $(awk 'END{print NR}' "$TMP/ext_rem.txt") tracked but not installed"
        while IFS= read -r l; do [ -n "$l" ] && printf "      %s+ %s%s\n" "$GREEN" "$l" "$RESET"; done < "$TMP/ext_add.txt"
        while IFS= read -r l; do [ -n "$l" ] && printf "      %s- %s%s\n" "$RED" "$l" "$RESET"; done < "$TMP/ext_rem.txt"
        CHANGES=$((CHANGES+1))
        EXT_DRIFT=yes
    fi
else
    info "code not on PATH — skipped"
fi

# ─── 3. iTerm2 profile ──────────────────────────────────────────────────
printf "\n%siTerm2 profile%s\n" "$BOLD" "$RESET"
PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
ITERM_FILE="$SCRIPT_DIR/iterm2/Default.json"
ITERM_DRIFT=""
if [ -f "$PLIST" ] && command -v plutil >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    if plutil -extract "New Bookmarks" json -o "$TMP/iterm_live.json" "$PLIST" 2>/dev/null; then
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
        if [ "$VERDICT" = SAME ]; then
            ok "in sync"
        else
            warn "differs from the copy in the repo"
            CHANGES=$((CHANGES+1)); ITERM_DRIFT=yes
        fi
    else
        info "could not read profiles from the plist — skipped"
    fi
else
    info "iTerm2 plist not found — skipped"
fi

# ─── 4. Tracked files already changed in git ────────────────────────────
printf "\n%sTracked files%s\n" "$BOLD" "$RESET"
cd "$SCRIPT_DIR" || exit 1
GIT_DIRTY="$(git status --porcelain 2>/dev/null)"
if [ -n "$GIT_DIRTY" ]; then
    printf "%s\n" "$GIT_DIRTY" | while IFS= read -r l; do printf "      %s%s%s\n" "$DIM" "$l" "$RESET"; done
else
    ok "nothing modified"
fi

# ─── Apply ──────────────────────────────────────────────────────────────
printf "\n"; rule
if [ "$CHANGES" -eq 0 ] && [ -z "$GIT_DIRTY" ]; then
    ok "Everything is already in sync."
    printf "\n"; exit 0
fi

if [ "$DRY_RUN" = true ]; then
    warn "Dry run — nothing was changed."
    printf "\n"; exit 0
fi

UPDATED=""
if [ "$CHANGES" -gt 0 ]; then
    printf "\n"
    if ask_yn "Update the repo to match this machine?" Y; then
        if [ -s "$TMP/added.txt" ]; then
            TARGET="$SCRIPT_DIR/Brewfile.$PROFILE"
            printf "\n  New packages go to a file of your choice:\n"
            printf "      %s1%s  Brewfile           %s(installed on every machine)%s\n" "$BOLD" "$RESET" "$DIM" "$RESET"
            printf "      %s2%s  Brewfile.%-9s %s(this machine's profile only)%s\n" "$BOLD" "$RESET" "$PROFILE" "$DIM" "$RESET"
            if [ "$INTERACTIVE" = true ]; then
                printf "  %s?%s Choice %s[2]%s " "$BOLD" "$RESET" "$DIM" "$RESET"
                read -r pick || pick=""
                [ "$pick" = 1 ] && TARGET="$SCRIPT_DIR/Brewfile"
            fi
            printf "\n# --- added by sync.sh ---\n" >> "$TARGET"
            cat "$TMP/added.txt" >> "$TARGET"
            ok "appended $(wc -l < "$TMP/added.txt" | tr -d ' ') entries to $(basename "$TARGET")"
            UPDATED="$UPDATED $(basename "$TARGET")"
        fi
        if [ "${EXT_DRIFT:-}" = yes ]; then
            code --list-extensions 2>/dev/null | sort > "$EXT_FILE"
            ok "rewrote vscode/extensions.txt"
            UPDATED="$UPDATED vscode/extensions.txt"
        fi
        if [ "$ITERM_DRIFT" = yes ]; then
            cp "$TMP/iterm_new.json" "$ITERM_FILE"
            ok "rewrote iterm2/Default.json"
            UPDATED="$UPDATED iterm2/Default.json"
        fi
    fi
fi

# ─── Commit ─────────────────────────────────────────────────────────────
if [ "$DO_COMMIT" = false ]; then
    printf "\n"; info "--no-commit given; review with: git diff"; printf "\n"; exit 0
fi

if [ -z "$(git status --porcelain)" ]; then
    printf "\n"; ok "Nothing to commit."; printf "\n"; exit 0
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
    if ask_yn "Push to $(git config --get remote.origin.url 2>/dev/null || echo origin)?" N; then
        git push && ok "pushed"
    else
        info "not pushed — run: git push"
    fi
else
    info "left uncommitted"
fi
printf "\n"
